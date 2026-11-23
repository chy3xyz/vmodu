// tx.v — Pool-backed transactions (holds one connection until commit/rollback).

module sql

// Tx pins a pool connection for BEGIN … COMMIT/ROLLBACK.
pub struct Tx {
mut:
	pool     &Pool
	conn     &Connection
	finished bool
}

// begin starts a transaction and holds a connection from the pool.
pub fn (mut p Pool) begin() !&Tx {
	if p.closed {
		return error('pool is closed')
	}
	mut conn := p.acquire()!
	match p.config.db_type {
		.sqlite {
			if mut sqlite_db := conn.sqlite_conn {
				sqlite_db.begin()!
			} else {
				p.release(mut conn)
				return error('sqlite connection missing')
			}
		}
		.mysql {
			if mysql_db := conn.mysql_conn {
				mysql_db.begin()!
			} else {
				p.release(mut conn)
				return error('mysql connection missing')
			}
		}
		.postgresql {
			if mut pg_db := conn.pg_conn {
				// PG begin requires PQTransactionParam; use default via exec
				pg_db.exec('BEGIN')!
			} else {
				p.release(mut conn)
				return error('postgresql connection missing')
			}
		}
	}
	return &Tx{
		pool:     p
		conn:     conn
		finished: false
	}
}

fn (mut t Tx) ensure_open() ! {
	if t.finished {
		return error('transaction is already finished')
	}
}

// exec_params runs a bound statement inside the transaction.
pub fn (mut t Tx) exec_params(query_sql string, params []string) ! {
	t.ensure_open()!
	match t.pool.config.db_type {
		.sqlite {
			if sqlite_db := t.conn.sqlite_conn {
				sqlite_db.exec_param_many(query_sql, params)!
				return
			}
		}
		.mysql {
			if mysql_db := t.conn.mysql_conn {
				mysql_db.exec_param_many(query_sql, params)!
				return
			}
		}
		.postgresql {
			if mut pg_db := t.conn.pg_conn {
				q := rewrite_qmarks_to_dollar(query_sql)
				pg_db.exec_param_many(q, params)!
				return
			}
		}
	}
	return error('no connection')
}

// query_params runs a bound query inside the transaction.
pub fn (mut t Tx) query_params(query_sql string, params []string) ![]Row {
	t.ensure_open()!
	match t.pool.config.db_type {
		.sqlite {
			if sqlite_db := t.conn.sqlite_conn {
				rows := sqlite_db.exec_param_many(query_sql, params)!
				return sqlite_rows_to_rows(rows)
			}
		}
		.mysql {
			if mysql_db := t.conn.mysql_conn {
				set := mysql_db.exec_param_many_result(query_sql, params)!
				return mysql_rowset_to_rows(set)
			}
		}
		.postgresql {
			if mut pg_db := t.conn.pg_conn {
				q := rewrite_qmarks_to_dollar(query_sql)
				res := pg_db.exec_param_many_result(q, params)!
				return pg_result_to_rows(res)
			}
		}
	}
	return error('no connection')
}

// execute runs raw SQL inside the transaction (trusted DDL only).
pub fn (mut t Tx) execute(query_sql string) ! {
	t.ensure_open()!
	match t.pool.config.db_type {
		.sqlite {
			if sqlite_db := t.conn.sqlite_conn {
				sqlite_db.exec(query_sql)!
				return
			}
		}
		.mysql {
			if mysql_db := t.conn.mysql_conn {
				mysql_db.query(query_sql)!
				return
			}
		}
		.postgresql {
			if mut pg_db := t.conn.pg_conn {
				pg_db.exec(query_sql)!
				return
			}
		}
	}
	return error('no connection')
}

// commit ends the transaction successfully and returns the connection to the pool.
pub fn (mut t Tx) commit() ! {
	t.ensure_open()!
	match t.pool.config.db_type {
		.sqlite {
			if mut sqlite_db := t.conn.sqlite_conn {
				sqlite_db.commit()!
			}
		}
		.mysql {
			if mysql_db := t.conn.mysql_conn {
				mysql_db.commit()!
			}
		}
		.postgresql {
			if mut pg_db := t.conn.pg_conn {
				pg_db.exec('COMMIT')!
			}
		}
	}
	t.finished = true
	t.pool.release(mut t.conn)
}

// rollback aborts the transaction and returns the connection to the pool.
pub fn (mut t Tx) rollback() ! {
	if t.finished {
		return
	}
	match t.pool.config.db_type {
		.sqlite {
			if mut sqlite_db := t.conn.sqlite_conn {
				sqlite_db.rollback()!
			}
		}
		.mysql {
			if mysql_db := t.conn.mysql_conn {
				mysql_db.rollback()!
			}
		}
		.postgresql {
			if mut pg_db := t.conn.pg_conn {
				pg_db.exec('ROLLBACK')!
			}
		}
	}
	t.finished = true
	t.pool.release(mut t.conn)
}
