// db.v - Database ORM and Connection Pool for VModulith
// Reuses: db.sqlite, db.mysql, db.pg from V standard library

module sql

import db.sqlite
import db.mysql
import db.pg
import time
import sync

// Database types
pub enum DBType {
	sqlite
	mysql
	postgresql
}

// Config for database connection
pub struct Config {
pub:
	db_type       DBType = .sqlite
	host          string = 'localhost'
	port          int    = 5432
	username      string
	password      string
	database      string
	max_connections int = 10
	max_idle_time   int = 3600  // seconds
	max_lifetime    int = 7200  // seconds
}

// Connection pool for database
pub struct Pool {
pub mut:
	config       Config
	connections  []Connection
	available    chan &Connection
	mu           sync.Mutex
	closed       bool
}

// Connection wrapper
pub struct Connection {
pub mut:
	sqlite_conn ?sqlite.DB
	mysql_conn  ?mysql.DB
	pg_conn     ?&pg.DB
	in_use      bool
	created_at  i64
	last_used   i64
}

// new_pool creates a new database connection pool
pub fn new_pool(config Config) !&Pool {
	mut pool := &Pool{
		config:      config
		connections: []
		available:   chan &Connection{cap: config.max_connections}
		closed:      false
	}
	
	// Initialize connections
	for _ in 0 .. config.max_connections {
		conn := pool.create_connection()!
		pool.connections << conn
		pool.available <- conn
	}
	
	return pool
}

// create_connection creates a new database connection
fn (mut p Pool) create_connection() !&Connection {
	mut conn := &Connection{
		in_use:     false
		created_at: time.now().unix()
		last_used:  time.now().unix()
	}
	
	match p.config.db_type {
		.sqlite {
			mut sqlite_db := sqlite.connect(p.config.database)!
			conn.sqlite_conn = sqlite_db
		}
		.mysql {
			mut mysql_db := mysql.connect(mysql.Config{
				host:     p.config.host
				port:     u32(p.config.port)
				username: p.config.username
				password: p.config.password
				dbname:   p.config.database
			})!
			conn.mysql_conn = mysql_db
		}
		.postgresql {
			mut pg_db := pg.connect(pg.Config{
				host:     p.config.host
				port:     p.config.port
				user:     p.config.username
				password: p.config.password
				dbname:   p.config.database
			}, pg.PoolConfig{})!
			conn.pg_conn = pg_db
		}
	}
	
	return conn
}

// acquire gets a connection from the pool
pub fn (mut p Pool) acquire() !&Connection {
	if p.closed {
		return error('pool is closed')
	}
	mut got := false
	mut conn := &Connection{}
	select {
		conn = <-p.available {
			got = true
		}
		5 * time.second {
			return error('timeout waiting for connection')
		}
	}
	if !got {
		return error('timeout waiting for connection')
	}
	conn.in_use = true
	conn.last_used = time.now().unix()
	return conn
}

// release returns a connection to the pool
pub fn (mut p Pool) release(mut conn Connection) {
	conn.in_use = false
	conn.last_used = time.now().unix()
	p.available <- conn
}

// close closes the pool and all connections
pub fn (mut p Pool) close() {
	p.closed = true
	
	for mut conn in p.connections {
		if mut sqlite_db := conn.sqlite_conn {
			sqlite_db.close() or {}
		}
		if mut mysql_db := conn.mysql_conn {
			mysql_db.close() or {}
		}
		if mut pg_db := conn.pg_conn {
			pg_db.close() or {}
		}
	}
}

// execute runs a SQL statement without bound parameters.
// Prefer exec_params / query_params for any untrusted values.
pub fn (mut p Pool) execute(query_sql string) ! {
	mut conn := p.acquire()!
	defer { p.release(mut conn) }

	match p.config.db_type {
		.sqlite {
			if sqlite_db := conn.sqlite_conn {
				sqlite_db.exec(query_sql)!
			}
		}
		.mysql {
			if mysql_db := conn.mysql_conn {
				mysql_db.query(query_sql)!
			}
		}
		.postgresql {
			if pg_db := conn.pg_conn {
				pg_db.exec(query_sql)!
			}
		}
	}
}

// rewrite_qmarks_to_dollar converts `?` placeholders to `$1`, `$2`, … (PostgreSQL).
fn rewrite_qmarks_to_dollar(query_sql string) string {
	mut out := []u8{cap: query_sql.len + 8}
	mut n := 0
	for c in query_sql {
		if c == `?` {
			n++
			out << `$`
			for ch in '${n}'.bytes() {
				out << ch
			}
		} else {
			out << c
		}
	}
	return out.bytestr()
}

// exec_params runs a statement with `?` placeholders (bound parameters).
// PostgreSQL: `?` is rewritten to `$n` automatically.
pub fn (mut p Pool) exec_params(query_sql string, params []string) ! {
	mut conn := p.acquire()!
	defer { p.release(mut conn) }

	match p.config.db_type {
		.sqlite {
			if sqlite_db := conn.sqlite_conn {
				sqlite_db.exec_param_many(query_sql, params)!
				return
			}
		}
		.mysql {
			if mysql_db := conn.mysql_conn {
				mysql_db.exec_param_many(query_sql, params)!
				return
			}
		}
		.postgresql {
			if mut pg_db := conn.pg_conn {
				q := rewrite_qmarks_to_dollar(query_sql)
				pg_db.exec_param_many(q, params)!
				return
			}
		}
	}
}

// query runs a SQL query without bound parameters.
// Prefer query_params for any untrusted values.
pub fn (mut p Pool) query(query_sql string) ![]Row {
	mut conn := p.acquire()!
	defer { p.release(mut conn) }

	match p.config.db_type {
		.sqlite {
			if sqlite_db := conn.sqlite_conn {
				rows := sqlite_db.exec(query_sql)!
				return sqlite_rows_to_rows(rows)
			}
		}
		.mysql {
			if mysql_db := conn.mysql_conn {
				result := mysql_db.query(query_sql)!
				return mysql_result_to_rows(result)
			}
		}
		.postgresql {
			if pg_db := conn.pg_conn {
				rows := pg_db.exec(query_sql)!
				return pg_rows_to_rows(rows)
			}
		}
	}

	return []
}

// query_params runs a query with `?` placeholders (bound parameters).
// PostgreSQL: `?` is rewritten to `$n` automatically.
pub fn (mut p Pool) query_params(query_sql string, params []string) ![]Row {
	mut conn := p.acquire()!
	defer { p.release(mut conn) }

	match p.config.db_type {
		.sqlite {
			if sqlite_db := conn.sqlite_conn {
				rows := sqlite_db.exec_param_many(query_sql, params)!
				return sqlite_rows_to_rows(rows)
			}
		}
		.mysql {
			if mysql_db := conn.mysql_conn {
				set := mysql_db.exec_param_many_result(query_sql, params)!
				return mysql_rowset_to_rows(set)
			}
		}
		.postgresql {
			if mut pg_db := conn.pg_conn {
				q := rewrite_qmarks_to_dollar(query_sql)
				res := pg_db.exec_param_many_result(q, params)!
				return pg_result_to_rows(res)
			}
		}
	}
	return []
}

// Row represents a database row
pub struct Row {
pub mut:
	columns []string
	values  map[string]string
}

// ORM Model trait
pub interface Model {
	table_name() string
	primary_key() string
	to_map() map[string]string
	from_map(map[string]string)
}

// Repository provides CRUD operations (parameterized values; SQLite-first).
pub struct Repository[T] {
pub mut:
	pool &Pool
}

// new_repository creates a new repository
pub fn new_repository[T](pool &Pool) Repository[T] {
	return Repository[T]{pool: pool}
}

fn require_safe_ident(name string, kind string) ! {
	if !is_safe_ident(name) {
		return error('unsafe ${kind} identifier: ${name}')
	}
}

fn is_safe_ident(s string) bool {
	if s.len == 0 {
		return false
	}
	for i, c in s {
		ok := (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_`
			|| (i > 0 && c >= `0` && c <= `9`)
		if !ok {
			return false
		}
	}
	return true
}

// find_by_id finds a record by primary key (id is bound, never interpolated).
pub fn (mut r Repository[T]) find_by_id(id string) !T {
	mut instance := T{}
	table := instance.table_name()
	pk := instance.primary_key()
	require_safe_ident(table, 'table')!
	require_safe_ident(pk, 'primary key')!

	q := 'SELECT * FROM ${table} WHERE ${pk} = ?'
	rows := r.pool.query_params(q, [id])!

	if rows.len == 0 {
		return error('record not found')
	}

	instance.from_map(rows[0].values)
	return instance
}

// find_all finds all records
pub fn (mut r Repository[T]) find_all() ![]T {
	mut instance := T{}
	table := instance.table_name()
	require_safe_ident(table, 'table')!

	q := 'SELECT * FROM ${table}'
	rows := r.pool.query(q)!

	mut results := []T{}
	for row in rows {
		mut item := T{}
		item.from_map(row.values)
		results << item
	}

	return results
}

// save inserts a record (column values are bound parameters).
pub fn (mut r Repository[T]) save(item T) ! {
	data := item.to_map()
	table := item.table_name()
	require_safe_ident(table, 'table')!

	mut columns := []string{}
	mut placeholders := []string{}
	mut params := []string{}

	for key, value in data {
		require_safe_ident(key, 'column')!
		columns << key
		placeholders << '?'
		params << value
	}

	if columns.len == 0 {
		return error('save: empty row')
	}

	q := 'INSERT INTO ${table} (${columns.join(', ')}) VALUES (${placeholders.join(', ')})'
	r.pool.exec_params(q, params)!
}

// delete removes a record by primary key (id is bound).
pub fn (mut r Repository[T]) delete(id string) ! {
	mut instance := T{}
	table := instance.table_name()
	pk := instance.primary_key()
	require_safe_ident(table, 'table')!
	require_safe_ident(pk, 'primary key')!

	q := 'DELETE FROM ${table} WHERE ${pk} = ?'
	r.pool.exec_params(q, [id])!
}

// Helper functions to convert native results to Row format
fn sqlite_rows_to_rows(sqlite_rows []sqlite.Row) []Row {
	mut rows := []Row{}
	for sr in sqlite_rows {
		mut values := map[string]string{}
		mut columns := []string{}
		if sr.names.len > 0 {
			columns = sr.names.clone()
			for i, name in sr.names {
				val := if i < sr.vals.len { sr.vals[i] } else { '' }
				values[name] = val
			}
		} else {
			for i, val in sr.vals {
				col := 'col${i}'
				columns << col
				values[col] = val
			}
		}
		rows << Row{
			columns: columns
			values:  values
		}
	}
	return rows
}

fn mysql_result_to_rows(result mysql.Result) []Row {
	// Legacy path via mysql.query; prefer exec_param_many + mysql_native_rows_to_rows
	_ = result
	return []
}

fn mysql_native_rows_to_rows(native []mysql.Row) []Row {
	mut rows := []Row{}
	for nr in native {
		mut values := map[string]string{}
		mut columns := []string{}
		for i, val in nr.vals {
			col := 'col${i}'
			columns << col
			values[col] = val
		}
		rows << Row{
			columns: columns
			values:  values
		}
	}
	return rows
}

fn mysql_rowset_to_rows(set mysql.RowSet) []Row {
	mut rows := []Row{}
	for nr in set.rows {
		mut values := map[string]string{}
		mut columns := []string{}
		for i, val in nr.vals {
			col := if i < set.names.len && set.names[i].len > 0 {
				set.names[i]
			} else {
				'col${i}'
			}
			columns << col
			values[col] = val
		}
		rows << Row{
			columns: columns
			values:  values
		}
	}
	return rows
}

fn pg_rows_to_rows(pg_rows []pg.Row) []Row {
	return pg_native_rows_to_rows(pg_rows)
}

fn pg_native_rows_to_rows(pg_rows []pg.Row) []Row {
	mut rows := []Row{}
	for nr in pg_rows {
		mut values := map[string]string{}
		mut columns := []string{}
		for i, opt in nr.vals {
			col := 'col${i}'
			columns << col
			values[col] = if v := opt { v } else { '' }
		}
		rows << Row{
			columns: columns
			values:  values
		}
	}
	return rows
}

fn pg_result_to_rows(res pg.Result) []Row {
	mut rows := []Row{}
	for nr in res.rows {
		mut values := map[string]string{}
		mut columns := []string{}
		for i, opt in nr.vals {
			col := if i < res.names.len && res.names[i].len > 0 {
				res.names[i]
			} else {
				'col${i}'
			}
			columns << col
			values[col] = if v := opt { v } else { '' }
		}
		rows << Row{
			columns: columns
			values:  values
		}
	}
	return rows
}
