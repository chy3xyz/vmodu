// ratelimit.v - Token-bucket rate limiter for HTTP server
module http

import sync
import time

// RateLimiter is a thread-safe token-bucket limiter.
// When disabled (rps <= 0), allow() always returns true.
@[heap]
pub struct RateLimiter {
mut:
	mu      sync.Mutex
	tokens  f64
	last_ms i64
	rps     f64
	burst   f64
	enabled bool
}

// new_rate_limiter creates a token-bucket limiter.
// rps <= 0 disables limiting. burst <= 0 uses max(1, rps).
pub fn new_rate_limiter(rps int, burst int) &RateLimiter {
	if rps <= 0 {
		return &RateLimiter{
			enabled: false
		}
	}
	effective_burst := if burst <= 0 { if rps > 1 { rps } else { 1 } } else { burst }
	now := time.now().unix_milli()
	return &RateLimiter{
		tokens:  f64(effective_burst)
		last_ms: now
		rps:     f64(rps)
		burst:   f64(effective_burst)
		enabled: true
	}
}

// allow consumes one token if available. Returns false when rate exceeded.
pub fn (mut r RateLimiter) allow() bool {
	if !r.enabled {
		return true
	}
	r.mu.lock()
	defer {
		r.mu.unlock()
	}

	now := time.now().unix_milli()
	elapsed := f64(now - r.last_ms) / 1000.0
	if elapsed > 0 {
		r.tokens += elapsed * r.rps
		if r.tokens > r.burst {
			r.tokens = r.burst
		}
		r.last_ms = now
	}

	if r.tokens < 1.0 {
		return false
	}
	r.tokens -= 1.0
	return true
}

// IpRateLimiter keeps a token bucket per client IP (wave 5).
@[heap]
pub struct IpRateLimiter {
mut:
	mu       sync.Mutex
	buckets  map[string]&RateLimiter
	rps      int
	burst    int
	max_keys int
	enabled  bool
}

// new_ip_rate_limiter creates a per-IP limiter. rps <= 0 disables.
// max_keys caps map size (evicts arbitrary keys when exceeded); <=0 => 10000.
pub fn new_ip_rate_limiter(rps int, burst int, max_keys int) &IpRateLimiter {
	if rps <= 0 {
		return &IpRateLimiter{
			enabled: false
			buckets: {}
		}
	}
	cap_keys := if max_keys > 0 { max_keys } else { 10000 }
	return &IpRateLimiter{
		buckets:  {}
		rps:      rps
		burst:    burst
		max_keys: cap_keys
		enabled:  true
	}
}

// allow returns false when the given IP exceeds its bucket.
pub fn (mut r IpRateLimiter) allow(ip string) bool {
	if !r.enabled {
		return true
	}
	key := if ip.len > 0 { ip } else { 'unknown' }
	r.mu.lock()
	mut lim := r.buckets[key] or {
		if r.buckets.len >= r.max_keys {
			// Evict one arbitrary key to bound memory
			for k, _ in r.buckets {
				r.buckets.delete(k)
				break
			}
		}
		created := new_rate_limiter(r.rps, r.burst)
		r.buckets[key] = created
		created
	}
	r.mu.unlock()
	return lim.allow()
}

// rate_limit_middleware returns Middleware that rejects with 429 when the bucket is empty.
pub fn rate_limit_middleware(rps int, burst int) Middleware {
	mut limiter := new_rate_limiter(rps, burst)
	return fn [mut limiter] (next HandlerFunc) HandlerFunc {
		return fn [mut limiter, next] (ctx Context) !Response {
			if !limiter.allow() {
				mut resp := new_response()
				resp.status_code = 429
				resp.headers = {
					'Content-Type': 'text/plain'
				}
				resp.body = 'Too Many Requests'
				return resp
			}
			return next(ctx)
		}
	}
}
