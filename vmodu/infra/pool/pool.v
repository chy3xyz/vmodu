// pool.v - Connection pool for efficient resource reuse
// v3.1: Refactored to remove unsafe { nil } patterns
//
// Features:
//   - Min/max pool size configuration
//   - Connection validation on acquire/release
//   - Statistics tracking
//   - Graceful shutdown
//
// Usage:
//   factory := fn () !Connection { return create_connection() }
//   validator := fn (c Connection) bool { return c.is_valid() }
//   mut pool := pool.new_pool(pool.Config{}, factory, validator)!

module pool

import time
import sync

// ============================================================================
// Interface
// ============================================================================

// Connection interface that pool elements must implement
pub interface Connection {
	is_valid() bool
	close() !
}

// Factory creates new connections
pub type Factory = fn () !Connection

// Validator checks if connection is valid
pub type Validator = fn (Connection) bool

// ============================================================================
// Data Structures
// ============================================================================

// Config for connection pool
pub struct Config {
pub mut:
	min_idle               int = 2
	max_open               int = 10
	max_lifetime_ms        int = 3600000  // 1 hour
	max_idle_time_ms       int = 600000   // 10 minutes
	acquire_timeout_ms     int = 5000
	validation_interval_ms int = 30000
}

// Stats tracks pool metrics
pub struct Stats {
pub mut:
	acquires_total      u64
	acquires_waited     u64
	acquire_duration_ms u64
	connections_open    int
	connections_idle    int
	hits                u64
	misses              u64
	timeouts            u64
	validation_failures u64
}

// Item is a wrapper for pooled connections with metadata
struct Item {
mut:
	conn       Connection
	created_at i64
	last_used  i64
}

// Pool manages a pool of connections
pub struct Pool {
pub mut:
	config    Config
	factory   ?Factory    // v3.1: Option type instead of unsafe nil
	validator ?Validator  // v3.1: Option type instead of unsafe nil

	idle   []Item
	all    []Item
	mu     sync.RwMutex

	closed bool
	stats  Stats
}

// ============================================================================
// Constructor Functions
// ============================================================================

// new_pool creates a new connection pool
pub fn new_pool(config Config, factory Factory, validator Validator) !&Pool {
	if config.min_idle > config.max_open {
		return error('min_idle cannot be greater than max_open')
	}

	mut p := &Pool{
		config:    config
		factory:   factory
		validator: validator
		idle:      []Item{cap: config.max_open}
		all:       []Item{cap: config.max_open}
	}

	// Create initial idle connections
	for _ in 0..config.min_idle {
		conn := factory() or { continue }
		item := Item{
			conn:       conn
			created_at: time.now().unix_milli()
			last_used:  time.now().unix_milli()
		}
		p.idle << item
		p.all << item
	}

	return p
}

// new_pool_with_defaults creates a pool with default factory/validator
pub fn new_pool_with_defaults(config Config) !&Pool {
	mut p := &Pool{
		config:    config
		factory:   none  // Must be set before use
		validator: none
		idle:      []Item{cap: config.max_open}
		all:       []Item{cap: config.max_open}
	}
	return p
}

// set_factory sets the connection factory
pub fn (mut p Pool) set_factory(factory Factory) {
	p.mu.lock()
	defer { p.mu.unlock() }
	p.factory = factory
}

// set_validator sets the connection validator
pub fn (mut p Pool) set_validator(validator Validator) {
	p.mu.lock()
	defer { p.mu.unlock() }
	p.validator = validator
}

// ============================================================================
// Core Operations
// ============================================================================

// acquire gets a connection from the pool
pub fn (mut p Pool) acquire() !Connection {
	if p.closed {
		return error('pool is closed')
	}

	p.stats.acquires_total++
	start := time.now().unix_milli()

	p.mu.lock()
	defer { p.mu.unlock() }

	// Try to get from idle pool
	if p.idle.len > 0 {
		item := p.idle.pop()
		p.stats.hits++
		p.update_acquire_stats(start)

		// Validate connection
		if f := p.validator {
			if !f(item.conn) {
				item.conn.close() or {}
				p.stats.validation_failures++
				return p.create_new()
			}
		}

		return item.conn
	}

	// No idle connection available
	p.stats.misses++

	// Check if we can create a new connection
	if p.all.len < p.config.max_open {
		return p.create_new()
	}

	return error('pool exhausted (max_open reached)')
}

// release returns a connection to the pool
pub fn (mut p Pool) release(conn Connection) {
	p.mu.lock()
	defer { p.mu.unlock() }

	if p.closed {
		conn.close() or {}
		return
	}

	// Validate before returning to pool
	if f := p.validator {
		if !f(conn) {
			conn.close() or {}
			p.remove_connection(conn)
			return
		}
	}

	// Add back to idle pool if there's room
	if p.idle.len < p.config.max_open {
		item := Item{
			conn:       conn
			created_at: time.now().unix_milli()
			last_used:  time.now().unix_milli()
		}
		p.idle << item
	} else {
		// Pool is full, close connection
		conn.close() or {}
		p.remove_connection(conn)
	}
}

// create_new creates a new connection
fn (mut p Pool) create_new() !Connection {
	f := p.factory or {
		return error('factory not set')
	}

	conn := f() or {
		return error('factory error: ${err}')
	}

	item := Item{
		conn:       conn
		created_at: time.now().unix_milli()
		last_used:  time.now().unix_milli()
	}
	p.all << item
	p.stats.connections_open = p.all.len

	return conn
}

// ============================================================================
// Lifecycle
// ============================================================================

// close closes all connections and the pool
pub fn (mut p Pool) close() ! {
	p.mu.lock()
	defer { p.mu.unlock() }

	if p.closed {
		return
	}

	p.closed = true

	// Close all idle connections
	for p.idle.len > 0 {
		item := p.idle.pop()
		item.conn.close() or {}
	}

	// Close all tracked connections
	for item in p.all {
		item.conn.close() or {}
	}
	p.all = []
	p.idle = []
}

// is_closed returns true if pool is closed
pub fn (p &Pool) is_closed() bool {
	return p.closed
}

// cleanup_idle removes excess idle connections
pub fn (mut p Pool) cleanup_idle() {
	p.mu.lock()
	defer { p.mu.unlock() }

	for p.idle.len > p.config.min_idle {
		item := p.idle.pop()
		item.conn.close() or {}
		p.remove_connection(item.conn)
	}
}

// ============================================================================
// Internal Helpers
// ============================================================================

// remove_connection removes a connection from tracking
fn (mut p Pool) remove_connection(conn Connection) {
	for i, item in p.all {
		if item.conn == conn {
			p.all.delete(i)
			break
		}
	}
	p.stats.connections_open = p.all.len
}

// update_acquire_stats updates timing stats
fn (mut p Pool) update_acquire_stats(start i64) {
	duration := time.now().unix_milli() - start
	p.stats.acquire_duration_ms += u64(duration)
}

// ============================================================================
// Query Operations
// ============================================================================

// get_stats returns pool statistics
pub fn (mut p Pool) get_stats() Stats {
	p.mu.rlock()
	defer { p.mu.runlock() }
	
	// Update current stats
	mut stats := p.stats
	stats.connections_idle = p.idle.len
	stats.connections_open = p.all.len
	return stats
}

// get_config returns pool configuration
pub fn (p &Pool) get_config() Config {
	return p.config
}

// has_factory returns true if factory is set
pub fn (p &Pool) has_factory() bool {
	return p.factory != none
}

// has_validator returns true if validator is set
pub fn (p &Pool) has_validator() bool {
	return p.validator != none
}
