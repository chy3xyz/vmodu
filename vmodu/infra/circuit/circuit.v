// circuit.v - Circuit Breaker pattern implementation
//
// State Machine: Closed -> Open -> Half-Open -> Closed
//
// Features:
//   - Configurable failure/success thresholds
//   - Automatic recovery with timeout
//   - Half-open probe requests
//   - State change callbacks
//
// Usage:
//   mut cb := circuit.new(name: 'api', failure_threshold: 5)
//   result := cb.execute(fn () !string {
//       return make_http_request()
//   })!

module circuit

import time
import sync

// ============================================================================
// Enums
// ============================================================================

// State represents circuit breaker state
pub enum State {
	closed    // Normal operation, requests pass through
	open      // Failing, requests are rejected
	half_open // Testing if service recovered
}

// String returns state name
pub fn (s State) str() string {
	return match s {
		.closed    { 'closed' }
		.open      { 'open' }
		.half_open { 'half-open' }
	}
}

// ============================================================================
// Data Structures
// ============================================================================

// Config for circuit breaker
pub struct Config {
pub mut:
	name                string
	failure_threshold   int = 5  // Failures to open
	success_threshold   int = 3  // Successes to close from half-open
	timeout_ms          int = 60000  // Time before attempting recovery
	half_open_max_calls int = 3  // Max calls in half-open state
}

// StateChangeCallback is called when circuit breaker state changes
pub type StateChangeCallback = fn (name string, old State, new State)

// CircuitBreaker protects operations from cascading failures
pub struct CircuitBreaker {
pub mut:
	config              Config
	state               State
	failures            int
	successes           int
	consecutive_successes int
	last_failure        i64
	calls_in_half_open  int
	mu                  sync.Mutex
	on_state_change     StateChangeCallback = fn (name string, old State, new State) {}
}

// Stats tracks circuit breaker statistics
pub struct Stats {
pub:
	state        State
	failures     int
	successes    int
	last_failure i64
}

// ============================================================================
// Constructor Functions
// ============================================================================

// new creates a circuit breaker
pub fn new(config Config) &CircuitBreaker {
	return &CircuitBreaker{
		config:          config
		state:           .closed
		failures:        0
		successes:       0
		on_state_change: fn (name string, old State, new State) {}  // no-op default
	}
}

// default creates a circuit breaker with default config
pub fn default(name string) &CircuitBreaker {
	return new(Config{name: name})
}

// ============================================================================
// Core Operations
// ============================================================================

// allow returns true if the operation should be allowed
pub fn (mut cb CircuitBreaker) allow() bool {
	cb.mu.lock()
	defer { cb.mu.unlock() }

	match cb.state {
		.closed {
			return true
		}
		.open {
			// Check if we should transition to half-open
			elapsed := time.now().unix_milli() - cb.last_failure
			if elapsed > cb.config.timeout_ms {
				cb.transition_to(.half_open)
				cb.calls_in_half_open = 0
				return true
			}
			return false
		}
		.half_open {
			if cb.calls_in_half_open < cb.config.half_open_max_calls {
				cb.calls_in_half_open++
				return true
			}
			return false
		}
	}
}

// record_success records a successful operation
pub fn (mut cb CircuitBreaker) record_success() {
	cb.mu.lock()
	defer { cb.mu.unlock() }

	match cb.state {
		.closed {
			cb.failures = 0
			cb.consecutive_successes++
		}
		.half_open {
			cb.consecutive_successes++
			if cb.consecutive_successes >= cb.config.success_threshold {
				cb.transition_to(.closed)
			}
		}
		else {}
	}
}

// record_failure records a failed operation
pub fn (mut cb CircuitBreaker) record_failure() {
	cb.mu.lock()
	defer { cb.mu.unlock() }

	cb.last_failure = time.now().unix_milli()
	cb.consecutive_successes = 0

	match cb.state {
		.closed {
			cb.failures++
			if cb.failures >= cb.config.failure_threshold {
				cb.transition_to(.open)
			}
		}
		.half_open {
			cb.transition_to(.open)
		}
		else {}
	}
}

// transition_to changes state and triggers callback
fn (mut cb CircuitBreaker) transition_to(new_state State) {
	old_state := cb.state
	cb.state = new_state

	// Reset counters
	cb.failures = 0
	cb.consecutive_successes = 0
	cb.calls_in_half_open = 0

	// Trigger callback
	cb.on_state_change(cb.config.name, old_state, new_state)
}

// ============================================================================
// Execute
// ============================================================================

// execute runs an operation with circuit breaker protection
pub fn (mut cb CircuitBreaker) execute(op fn () !string) !string {
	if !cb.allow() {
		return error('circuit breaker open')
	}

	result := op() or {
		cb.record_failure()
		return err
	}

	cb.record_success()
	return result
}

// ============================================================================
// Query Operations
// ============================================================================

// get_state returns current state
pub fn (mut cb CircuitBreaker) get_state() State {
	cb.mu.lock()
	defer { cb.mu.unlock() }
	return cb.state
}

// get_stats returns current statistics
pub fn (mut cb CircuitBreaker) get_stats() Stats {
	cb.mu.lock()
	defer { cb.mu.unlock() }

	return Stats{
		state:        cb.state
		failures:     cb.failures
		successes:    cb.successes
		last_failure: cb.last_failure
	}
}

// reset forces circuit breaker to closed state
pub fn (mut cb CircuitBreaker) reset() {
	cb.mu.lock()
	defer { cb.mu.unlock() }
	cb.transition_to(.closed)
}

// ============================================================================
// Manager (Multi-CB Management)
// ============================================================================

// Manager manages multiple circuit breakers
pub struct Manager {
pub mut:
	breakers map[string]&CircuitBreaker
	mu       sync.RwMutex
	config   Config  // Default config
}

// new_manager creates a circuit breaker manager
pub fn new_manager(config Config) &Manager {
	return &Manager{
		breakers: {}
		config:   config
	}
}

// get_or_create returns existing or creates new circuit breaker
pub fn (mut m Manager) get_or_create(name string) &CircuitBreaker {
	m.mu.rlock()
	unsafe {
		cb := m.breakers[name]
		if cb != 0 {
			m.mu.runlock()
			return cb
		}
	}
	m.mu.runlock()

	m.mu.lock()
	defer { m.mu.unlock() }

	// Double-check after acquiring write lock
	if cb2 := m.breakers[name] {
		return cb2
	}

	config := Config{
		...m.config
		name: name
	}

	new_cb := new(config)
	m.breakers[name] = new_cb
	return new_cb
}

// get returns circuit breaker by name
pub fn (mut m Manager) get(name string) ?&CircuitBreaker {
	m.mu.rlock()
	defer { m.mu.runlock() }

	return m.breakers[name] or { return none }
}

// remove deletes a circuit breaker
pub fn (mut m Manager) remove(name string) {
	m.mu.lock()
	defer { m.mu.unlock() }
	m.breakers.delete(name)
}

// get_all returns all circuit breakers
pub fn (mut m Manager) get_all() map[string]&CircuitBreaker {
	m.mu.rlock()
	defer { m.mu.runlock() }

	// Return copy
	mut result := map[string]&CircuitBreaker{}
	for k, v in m.breakers {
		result[k] = v
	}
	return result
}

// ============================================================================
// Async Wrapper
// ============================================================================

// AsyncBreaker wraps CircuitBreaker for async operations
pub struct AsyncBreaker {
pub mut:
	breaker &CircuitBreaker
}

// call executes operation asynchronously
pub fn (mut ab AsyncBreaker) call(op fn () !string, callback fn (string, string)) {
	spawn fn [mut ab, op, callback] () {
		result := ab.breaker.execute(op) or {
			callback('', err.msg())
			return
		}
		callback(result, '')
	}()
}
