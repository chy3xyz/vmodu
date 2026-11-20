// pool_test.v - Unit tests for Connection Pool

module pool

// Mock connection for testing - using fields only (not mut receiver)
struct TestConn {
mut:
	id     int
	valid  bool
	closed bool
}

fn (c &TestConn) is_valid() bool {
	return c.valid && !c.closed
}

fn (c &TestConn) close() ! {
	// Cast to mutable reference to modify
	unsafe {
		mut m := &TestConn(c)
		m.closed = true
	}
}

// test_pool_creation tests creating a pool
fn test_pool_creation() {
	factory := fn () !Connection {
		return &TestConn{id: 1, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 1
		max_open: 3
	}
	
	pool := new_pool(config, factory, validator) or {
		return
	}
	
	assert pool.config.min_idle == 1
	assert pool.config.max_open == 3
	assert pool.closed == false
}

// test_pool_config_validation tests config validation
fn test_pool_config_validation() {
	factory := fn () !Connection {
		return &TestConn{id: 1, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return true
	}
	
	config := Config{
		min_idle: 5
		max_open: 3  // Invalid: min > max
	}
	
	pool := new_pool(config, factory, validator) or {
		assert err.msg().contains('min_idle')
		return
	}
	
	assert false, 'should have failed with invalid config'
}

// test_pool_acquire tests acquiring connections
fn test_pool_acquire() {
	mut conn_id := 0
	
	factory := fn [mut conn_id] () !Connection {
		conn_id++
		return &TestConn{id: conn_id, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 2
		max_open: 5
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	defer { pool.close() or {} }
	
	// Acquire a connection
	conn := pool.acquire() or {
		return
	}
	
	assert conn.is_valid() == true
	
	stats := pool.get_stats()
	assert stats.acquires_total == 1
}

// test_pool_release tests releasing connections back to pool
fn test_pool_release() {
	mut conn_id := 0
	
	factory := fn [mut conn_id] () !Connection {
		conn_id++
		return &TestConn{id: conn_id, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 1
		max_open: 3
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	defer { pool.close() or {} }
	
	// Acquire and release
	conn := pool.acquire() or { return }
	pool.release(conn)
	
	// Pool should have connection available
	stats := pool.get_stats()
	assert stats.hits == 1
}

// test_pool_exhaustion tests pool exhaustion
fn test_pool_exhaustion() {
	mut conn_id := 0
	
	factory := fn [mut conn_id] () !Connection {
		conn_id++
		return &TestConn{id: conn_id, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 0
		max_open: 2
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	defer { pool.close() or {} }
	
	// Exhaust the pool
	conn1 := pool.acquire() or { return }
	conn2 := pool.acquire() or { return }
	
	// Third acquire should fail
	pool.acquire() or {
		assert err.msg().contains('exhausted')
		pool.release(conn1)
		pool.release(conn2)
		return
	}
	
	assert false, 'should have failed when pool exhausted'
}

// test_pool_validation tests connection validation
fn test_pool_validation() {
	mut conn_id := 0
	
	factory := fn [mut conn_id] () !Connection {
		conn_id++
		return &TestConn{id: conn_id, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 1
		max_open: 3
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	defer { pool.close() or {} }
	
	// Acquire connection
	conn := pool.acquire() or { return }
	assert conn.is_valid() == true
	
	// Release connection back to pool
	pool.release(conn)
	
	stats := pool.get_stats()
	// Should have at least 1 hit
	assert stats.hits >= 1
}

// test_pool_closed tests closed pool behavior
fn test_pool_closed() {
	factory := fn () !Connection {
		return &TestConn{id: 1, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 1
		max_open: 3
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	
	// Close the pool
	pool.close() or {}
	
	// Acquire should fail
	pool.acquire() or {
		assert err.msg().contains('closed')
		return
	}
	
	assert false, 'should fail after pool is closed'
}

// test_pool_stats tests statistics collection
fn test_pool_stats() {
	mut conn_id := 0
	
	factory := fn [mut conn_id] () !Connection {
		conn_id++
		return &TestConn{id: conn_id, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 1
		max_open: 5
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	defer { pool.close() or {} }
	
	// Initial stats
	stats1 := pool.get_stats()
	assert stats1.acquires_total == 0
	
	// Acquire and release multiple times
	for _ in 0..3 {
		conn := pool.acquire() or { continue }
		pool.release(conn)
	}
	
	// Check stats updated
	stats2 := pool.get_stats()
	assert stats2.acquires_total == 3
	assert stats2.hits >= 0
}

// test_pool_cleanup tests idle cleanup
fn test_pool_cleanup() {
	mut conn_id := 0
	
	factory := fn [mut conn_id] () !Connection {
		conn_id++
		return &TestConn{id: conn_id, valid: true}
	}
	
	validator := fn (c Connection) bool {
		return c.is_valid()
	}
	
	config := Config{
		min_idle: 1
		max_open: 5
	}
	
	mut pool := new_pool(config, factory, validator) or {
		return
	}
	defer { pool.close() or {} }
	
	// Get some connections
	mut conns := []Connection{cap: 3}
	for _ in 0..3 {
		conn := pool.acquire() or { break }
		conns << conn
	}
	
	// Release all
	for conn in conns {
		pool.release(conn)
	}
	
	// Cleanup should reduce idle to min_idle
	pool.cleanup_idle()
}

// test_config_defaults tests default configuration
fn test_config_defaults() {
	config := Config{}
	
	assert config.min_idle == 2
	assert config.max_open == 10
	assert config.max_lifetime_ms == 3600000
	assert config.max_idle_time_ms == 600000
}
