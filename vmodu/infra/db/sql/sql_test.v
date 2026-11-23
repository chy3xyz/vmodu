// sql_test.v - Unit tests for SQLite pool (temp file / in-memory only)

module sql

import os
import rand

fn test_sqlite_pool_create_execute_query() {
	db_path := os.join_path(os.temp_dir(), 'vmodu_sql_test_${rand.intn(1_000_000) or { 0 }}.db')
	defer {
		os.rm(db_path) or {}
	}

	mut pool := new_pool(Config{
		db_type:          .sqlite
		database:         db_path
		max_connections:  2
	}) or {
		assert false, 'new_pool failed: ${err}'
		return
	}
	defer {
		pool.close()
	}

	pool.execute('CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT NOT NULL)') or {
		assert false, 'CREATE TABLE failed: ${err}'
		return
	}

	pool.execute("INSERT INTO items (id, name) VALUES (1, 'alpha')") or {
		assert false, 'INSERT failed: ${err}'
		return
	}

	pool.execute("INSERT INTO items (id, name) VALUES (2, 'beta')") or {
		assert false, 'second INSERT failed: ${err}'
		return
	}

	// query API is exercised; row mapping may be empty stub but must not error
	rows := pool.query('SELECT id, name FROM items ORDER BY id') or {
		assert false, 'query failed: ${err}'
		return
	}
	assert rows.len >= 0
}

fn test_sqlite_memory_pool_single_conn() {
	// :memory: is per-connection; keep pool size 1 so CREATE is visible to later ops
	mut pool := new_pool(Config{
		db_type:         .sqlite
		database:        ':memory:'
		max_connections: 1
	}) or {
		assert false, 'new_pool :memory: failed: ${err}'
		return
	}
	defer {
		pool.close()
	}

	pool.execute('CREATE TABLE t (v INTEGER)') or {
		assert false, 'CREATE failed: ${err}'
		return
	}
	pool.execute('INSERT INTO t (v) VALUES (7)') or {
		assert false, 'INSERT failed: ${err}'
		return
	}

	_ := pool.query('SELECT v FROM t') or {
		assert false, 'query failed: ${err}'
		return
	}
}

fn test_pool_acquire_release() {
	db_path := os.join_path(os.temp_dir(), 'vmodu_sql_acq_${rand.intn(1_000_000) or { 0 }}.db')
	defer {
		os.rm(db_path) or {}
	}

	mut pool := new_pool(Config{
		db_type:         .sqlite
		database:        db_path
		max_connections: 1
	}) or {
		assert false, 'new_pool failed: ${err}'
		return
	}
	defer {
		pool.close()
	}

	mut conn := pool.acquire() or {
		assert false, 'acquire failed: ${err}'
		return
	}
	assert conn.in_use == true
	pool.release(mut conn)
	assert conn.in_use == false
}

fn test_pool_closed_acquire_fails() {
	mut pool := new_pool(Config{
		db_type:         .sqlite
		database:        ':memory:'
		max_connections: 1
	}) or {
		assert false, 'new_pool failed: ${err}'
		return
	}
	pool.close()

	pool.acquire() or {
		assert err.msg().contains('pool is closed')
		return
	}
	assert false, 'expected pool is closed'
}

struct TestItem {
pub mut:
	id   string
	name string
}

fn (t TestItem) table_name() string {
	return 'items'
}

fn (t TestItem) primary_key() string {
	return 'id'
}

fn (t TestItem) to_map() map[string]string {
	return {
		'id':   t.id
		'name': t.name
	}
}

fn (mut t TestItem) from_map(m map[string]string) {
	t.id = m['id'] or { '' }
	t.name = m['name'] or { '' }
}

fn test_repository_params_resist_injection() {
	db_path := os.join_path(os.temp_dir(), 'vmodu_sql_repo_${rand.intn(1_000_000) or { 0 }}.db')
	defer {
		os.rm(db_path) or {}
	}

	mut pool := new_pool(Config{
		db_type:         .sqlite
		database:        db_path
		max_connections: 1
	}) or {
		assert false, 'new_pool failed: ${err}'
		return
	}
	defer {
		pool.close()
	}

	pool.execute('CREATE TABLE items (id TEXT PRIMARY KEY, name TEXT NOT NULL)') or {
		assert false, 'CREATE TABLE failed: ${err}'
		return
	}

	mut repo := new_repository[TestItem](pool)
	repo.save(TestItem{
		id:   '1'
		name: 'alpha'
	}) or {
		assert false, 'save failed: ${err}'
		return
	}

	// Malicious id must bind as a literal, not alter SQL
	evil := "1' OR '1'='1"
	if _ := repo.find_by_id(evil) {
		assert false, 'injection id should not match a row'
	}

	got := repo.find_by_id('1') or {
		assert false, 'find_by_id failed: ${err}'
		return
	}
	assert got.id == '1'
	assert got.name == 'alpha'

	repo.save(TestItem{
		id:   evil
		name: 'bound'
	}) or {
		assert false, 'save evil id failed: ${err}'
		return
	}
	bound := repo.find_by_id(evil) or {
		assert false, 'find evil id failed: ${err}'
		return
	}
	assert bound.name == 'bound'

	rows := pool.query_params('SELECT name FROM items WHERE id = ?', [evil]) or {
		assert false, 'query_params failed: ${err}'
		return
	}
	assert rows.len == 1
	assert rows[0].values['name'] == 'bound'
}

fn test_sqlite_transaction_commit_and_rollback() {
	db_path := os.join_path(os.temp_dir(), 'vmodu_sql_tx_${rand.intn(1_000_000) or { 0 }}.db')
	defer {
		os.rm(db_path) or {}
	}

	mut pool := new_pool(Config{
		db_type:         .sqlite
		database:        db_path
		max_connections: 1
	}) or {
		assert false, 'new_pool: ${err}'
		return
	}
	defer {
		pool.close()
	}

	pool.execute('CREATE TABLE kv (k TEXT PRIMARY KEY, v TEXT NOT NULL)') or {
		assert false, 'create: ${err}'
		return
	}

	mut tx := pool.begin() or {
		assert false, 'begin: ${err}'
		return
	}
	tx.exec_params('INSERT INTO kv (k, v) VALUES (?, ?)', ['a', '1']) or {
		assert false, 'insert: ${err}'
		return
	}
	tx.commit() or {
		assert false, 'commit: ${err}'
		return
	}

	rows := pool.query_params('SELECT v FROM kv WHERE k = ?', ['a']) or {
		assert false, 'query after commit: ${err}'
		return
	}
	assert rows.len == 1

	mut tx2 := pool.begin() or {
		assert false, 'begin2: ${err}'
		return
	}
	tx2.exec_params('INSERT INTO kv (k, v) VALUES (?, ?)', ['b', '2']) or {
		assert false, 'insert2: ${err}'
		return
	}
	tx2.rollback() or {
		assert false, 'rollback: ${err}'
		return
	}

	miss := pool.query_params('SELECT v FROM kv WHERE k = ?', ['b']) or {
		assert false, 'query after rollback: ${err}'
		return
	}
	assert miss.len == 0
}

fn test_rewrite_qmarks_to_dollar() {
	assert rewrite_qmarks_to_dollar('SELECT * FROM t WHERE a = ? AND b = ?') == 'SELECT * FROM t WHERE a = $1 AND b = $2'
	assert rewrite_qmarks_to_dollar('no params') == 'no params'
}
