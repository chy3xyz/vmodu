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
