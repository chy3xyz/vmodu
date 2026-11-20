// redis.v - Redis Client for VModulith
// Reuses: net.tcp for connection, encoding for serialization

module cache

import net
import time
import sync
import json2
import rand

// Redis client configuration
pub struct RedisConfig {
pub:
	host           string = 'localhost'
	port           int    = 6379
	password       string
	db             int    = 0
	max_retries    int    = 3
	retry_delay_ms int    = 100
	pool_size      int    = 10
}

// Redis client
pub struct RedisClient {
pub mut:
	config      RedisConfig
	pool        []net.TcpConn
	available   chan net.TcpConn
	mu          sync.Mutex
	closed      bool
}

// new_redis_client creates a new Redis client
pub fn new_redis_client(config RedisConfig) !&RedisClient {
	mut client := &RedisClient{
		config:    config
		pool:      []net.TcpConn{}
		available: chan net.TcpConn{cap: config.pool_size}
		closed:    false
	}
	
	// Initialize connection pool
	for _ in 0 .. config.pool_size {
		conn := client.connect()!
		client.pool << conn
		client.available <- conn
	}
	
	return client
}

// connect creates a new Redis connection
fn (mut r RedisClient) connect() !net.TcpConn {
	mut conn := net.dial_tcp('${r.config.host}:${r.config.port}')!
	
	// Authenticate if password provided
	if r.config.password != '' {
		r.send_command(mut conn, 'AUTH ${r.config.password}')!
		response := r.read_response(mut conn)!
		if !response.starts_with('+OK') {
			return error('authentication failed')
		}
	}
	
	// Select database
	if r.config.db > 0 {
		r.send_command(mut conn, 'SELECT ${r.config.db}')!
		response := r.read_response(mut conn)!
		if !response.starts_with('+OK') {
			return error('database selection failed')
		}
	}
	
	return conn
}

// acquire gets a connection from the pool
fn (mut r RedisClient) acquire() !net.TcpConn {
	if r.closed {
		return error('client is closed')
	}
	
	select {
		conn := <-r.available {
			return conn
		}
		5 * time.second {
			return error('timeout waiting for connection')
		}
	}
}

// release returns a connection to the pool
fn (mut r RedisClient) release(conn net.TcpConn) {
	r.available <- conn
}

// send_command sends a Redis command
fn (mut r RedisClient) send_command(mut conn net.TcpConn, cmd string) ! {
	conn.write('${cmd}\r\n'.bytes())!
}

// read_response reads Redis response
fn (mut r RedisClient) read_response(mut conn net.TcpConn) !string {
	mut buf := []u8{len: 4096}
	n := conn.read(mut buf)!
	if n == 0 {
		return error('connection closed')
	}
	return buf[..n].bytestr().trim_space()
}

// SET key value
pub fn (mut r RedisClient) set(key string, value string, expire_seconds int) ! {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	mut cmd := 'SET "${key}" "${value}"'
	if expire_seconds > 0 {
		cmd += ' EX ${expire_seconds}'
	}
	
	r.send_command(mut conn, cmd)!
	response := r.read_response(mut conn)!
	
	if !response.starts_with('+OK') {
		return error('SET failed: ${response}')
	}
}

// GET key
pub fn (mut r RedisClient) get(key string) !string {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'GET "${key}"')!
	response := r.read_response(mut conn)!
	
	if response.starts_with('$-1') {
		return error('key not found')
	}
	
	if response.starts_with('$') {
		// Bulk string response
		parts := response.split('\r\n')
		if parts.len >= 2 {
			return parts[1]
		}
	}
	
	return response
}

// DEL key
pub fn (mut r RedisClient) del(key string) !bool {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'DEL "${key}"')!
	response := r.read_response(mut conn)!
	
	// Response: :1\r\n (deleted) or :0\r\n (not found)
	return response.starts_with(':1')
}

// EXISTS key
pub fn (mut r RedisClient) exists(key string) !bool {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'EXISTS "${key}"')!
	response := r.read_response(mut conn)!
	
	return response.starts_with(':1')
}

// EXPIRE key seconds
pub fn (mut r RedisClient) expire(key string, seconds int) !bool {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'EXPIRE "${key}" ${seconds}')!
	response := r.read_response(mut conn)!
	
	return response.starts_with(':1')
}

// INCR key
pub fn (mut r RedisClient) incr(key string) !i64 {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'INCR "${key}"')!
	response := r.read_response(mut conn)!
	
	// Response: :<number>\r\n
	if response.starts_with(':') {
		return response[1..].i64()
	}
	
	return error('INCR failed: ${response}')
}

// DECR key
pub fn (mut r RedisClient) decr(key string) !i64 {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'DECR "${key}"')!
	response := r.read_response(mut conn)!
	
	if response.starts_with(':') {
		return response[1..].i64()
	}
	
	return error('DECR failed: ${response}')
}

// HSET hash field value
pub fn (mut r RedisClient) hset(hash string, field string, value string) ! {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'HSET "${hash}" "${field}" "${value}"')!
	response := r.read_response(mut conn)!
	
	if !response.starts_with(':') {
		return error('HSET failed: ${response}')
	}
}

// HGET hash field
pub fn (mut r RedisClient) hget(hash string, field string) !string {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'HGET "${hash}" "${field}"')!
	response := r.read_response(mut conn)!
	
	if response.starts_with('$-1') {
		return error('field not found')
	}
	
	if response.starts_with('$') {
		parts := response.split('\r\n')
		if parts.len >= 2 {
			return parts[1]
		}
	}
	
	return response
}

// LPUSH list value
pub fn (mut r RedisClient) lpush(list string, value string) ! {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'LPUSH "${list}" "${value}"')!
	response := r.read_response(mut conn)!
	
	if !response.starts_with(':') {
		return error('LPUSH failed: ${response}')
	}
}

// RPOP list
pub fn (mut r RedisClient) rpop(list string) !string {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'RPOP "${list}"')!
	response := r.read_response(mut conn)!
	
	if response.starts_with('$-1') {
		return error('list empty')
	}
	
	if response.starts_with('$') {
		parts := response.split('\r\n')
		if parts.len >= 2 {
			return parts[1]
		}
	}
	
	return response
}

// PUBLISH channel message
pub fn (mut r RedisClient) publish(channel string, message string) !int {
	mut conn := r.acquire()!
	defer { r.release(conn) }
	
	r.send_command(mut conn, 'PUBLISH "${channel}" "${message}"')!
	response := r.read_response(mut conn)!
	
	if response.starts_with(':') {
		return response[1..].int()
	}
	
	return error('PUBLISH failed: ${response}')
}

// close closes the Redis client
pub fn (mut r RedisClient) close() {
	r.closed = true
	
	for conn in r.pool {
		conn.close() or {}
	}
}

// Cache helper functions

// Cache struct for common caching patterns
pub struct Cache {
pub mut:
	client &RedisClient
	prefix string
	default_ttl int = 3600  // 1 hour
}

// new_cache creates a new cache instance
pub fn new_cache(client &RedisClient, prefix string) Cache {
	return Cache{
		client: client
		prefix: prefix
	}
}

// get retrieves a value and deserializes it
pub fn (c &Cache) get[T](key string) !T {
	full_key := '${c.prefix}:${key}'
	data := c.client.get(full_key)!
	return json2.decode[T](data)!
}

// set stores a value with serialization
pub fn (c &Cache) set[T](key string, value T, ttl int) ! {
	full_key := '${c.prefix}:${key}'
	data := json2.encode(value, escape_unicode: true, time_as_unix: true)
	expire := if ttl > 0 { ttl } else { c.default_ttl }
	c.client.set(full_key, data, expire)!
}

// delete removes a key
pub fn (c &Cache) delete(key string) !bool {
	full_key := '${c.prefix}:${key}'
	return c.client.del(full_key)!
}

// exists checks if key exists
pub fn (c &Cache) exists(key string) !bool {
	full_key := '${c.prefix}:${key}'
	return c.client.exists(full_key)!
}

// Distributed lock using Redis
pub struct DistributedLock {
pub mut:
	client  &RedisClient
	key     string
	token   string
	ttl     int  // seconds
}

// new_lock creates a new distributed lock
pub fn new_lock(client &RedisClient, key string, ttl int) DistributedLock {
	return DistributedLock{
		client: client
		key: 'lock:${key}'
		token: '${time.now().unix()}_${rand.intn(1000000) or { 0 }}'
		ttl: ttl
	}
}

// acquire tries to acquire the lock
pub fn (mut l DistributedLock) acquire() !bool {
	// Use SET NX EX for atomic lock acquisition
	mut conn := l.client.acquire()!
	defer { l.client.release(conn) }
	
	l.client.send_command(mut conn, 'SET "${l.key}" "${l.token}" NX EX ${l.ttl}')!
	response := l.client.read_response(mut conn)!
	
	return response.starts_with('+OK')
}

// release releases the lock
pub fn (mut l DistributedLock) release() !bool {
	// Only release if we own the lock (token matches)
	current_token := l.client.get(l.key) or { return true }  // Already expired
	
	if current_token != l.token {
		return false  // We don't own the lock
	}
	
	return l.client.del(l.key)!
}

// Rate limiter using Redis
pub struct RateLimiter {
pub mut:
	client &RedisClient
	key_prefix string
	max_requests int
	window_seconds int
}

// new_rate_limiter creates a new rate limiter
pub fn new_rate_limiter(client &RedisClient, key_prefix string, max_requests int, window_seconds int) RateLimiter {
	return RateLimiter{
		client: client
		key_prefix: key_prefix
		max_requests: max_requests
		window_seconds: window_seconds
	}
}

// check checks if request is allowed
pub fn (mut r RateLimiter) check(identifier string) !bool {
	key := 'ratelimit:${r.key_prefix}:${identifier}'
	
	current := r.client.incr(key) or { 1 }
	
	if current == 1 {
		// First request, set expiration
		r.client.expire(key, r.window_seconds)!
	}
	
	return current <= r.max_requests
}

// remaining returns remaining requests
pub fn (mut r RateLimiter) remaining(identifier string) !int {
	key := 'ratelimit:${r.key_prefix}:${identifier}'
	
	current := r.client.get(key) or { return r.max_requests }
	count := current.i64()
	
	if count >= r.max_requests {
		return 0
	}
	
	return r.max_requests - int(count)
}
