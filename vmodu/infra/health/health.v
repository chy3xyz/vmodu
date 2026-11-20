// health.v - Health check system for VModulith Runtime
//
// Features:
//   - Component-based health checks
//   - Status aggregation (healthy -> degraded -> unhealthy)
//   - Health history tracking
//   - HTTP-friendly response format
//
// Usage:
//   mut checker := health.default_checker()
//   checker.register('database', fn () ComponentHealth {
//       return ComponentHealth{status: .healthy, message: 'Connected'}
//   })!
//   report := checker.run_checks()

module health

import time
import sync

// ============================================================================
// Enums
// ============================================================================

// Status represents health status
pub enum Status {
	unknown
	healthy
	degraded
	unhealthy
}

// String returns status name
pub fn (s Status) str() string {
	return match s {
		.unknown   { 'unknown' }
		.healthy   { 'healthy' }
		.degraded  { 'degraded' }
		.unhealthy { 'unhealthy' }
	}
}

// ============================================================================
// Data Structures
// ============================================================================

// ComponentHealth represents health of a single component
pub struct ComponentHealth {
pub:
	name        string
	status      Status
	message     string
	last_check  i64
	response_ms int
}

// HealthReport is the overall health report
pub struct HealthReport {
pub:
	status      Status
	timestamp   i64
	components  []ComponentHealth
	version     string
}

// CheckerConfig for health checker
pub struct CheckerConfig {
pub mut:
	check_interval_ms int  = 30000 // How often to run checks
	history_size      int  = 10    // Keep last N results per component
	strict_mode       bool         // One unhealthy = overall unhealthy
}

// Check is a health check function
pub type Check = fn () ComponentHealth

// Checker manages health checks
pub struct Checker {
pub mut:
	checks     map[string]Check
	results    map[string]ComponentHealth
	history    map[string][]ComponentHealth
	mu         sync.RwMutex
	config     CheckerConfig
	version    string
}

// ============================================================================
// Constructor Functions
// ============================================================================

// new_checker creates a new health checker
pub fn new_checker(config CheckerConfig) &Checker {
	return &Checker{
		checks:  {}
		results: {}
		history: {}
		config:  config
		version: 'v3.0.0'
	}
}

// default_checker creates a checker with default config
pub fn default_checker() &Checker {
	return new_checker(CheckerConfig{})
}

// ============================================================================
// Registration
// ============================================================================

// register adds a health check
pub fn (mut c Checker) register(name string, check Check) ! {
	c.mu.lock()
	defer { c.mu.unlock() }

	if name in c.checks {
		return error('health check already registered: ${name}')
	}

	c.checks[name] = check
	c.history[name] = []ComponentHealth{cap: c.config.history_size}
}

// unregister removes a health check
pub fn (mut c Checker) unregister(name string) {
	c.mu.lock()
	defer { c.mu.unlock() }

	c.checks.delete(name)
	c.results.delete(name)
	c.history.delete(name)
}

// ============================================================================
// Health Checks
// ============================================================================

// run_checks executes all registered health checks
pub fn (mut c Checker) run_checks() HealthReport {
	c.mu.rlock()
	check_names := c.checks.keys()
	c.mu.runlock()

	mut components := []ComponentHealth{cap: check_names.len}
	mut overall_status := Status.healthy

	for name in check_names {
		component := c.run_single_check(name)
		components << component
		overall_status = c.aggregate_status(overall_status, component.status)
	}

	return HealthReport{
		status:     overall_status
		timestamp:  time.now().unix_milli()
		components: components
		version:    c.version
	}
}

// run_single_check executes a single health check
fn (mut c Checker) run_single_check(name string) ComponentHealth {
	c.mu.rlock()
	check := c.checks[name] or { 
		c.mu.runlock()
		return ComponentHealth{name: name, status: .unknown, message: 'Check not found'}
	}
	c.mu.runlock()

	start := time.now().unix_milli()
	result := check()
	duration := int(time.now().unix_milli() - start)

	component := ComponentHealth{
		name:        name
		status:      result.status
		message:     result.message
		last_check:  time.now().unix_milli()
		response_ms: duration
	}

	// Store result and history
	c.mu.lock()
	c.results[name] = component

	mut hist := c.history[name]
	hist << component
	if hist.len > c.config.history_size {
		hist = unsafe { hist[1..] }
	}
	c.history[name] = hist
	c.mu.unlock()

	return component
}

// aggregate_status combines two statuses, returning the more severe one
fn (c &Checker) aggregate_status(current Status, new Status) Status {
	// Priority: unhealthy > degraded > unknown > healthy
	if new == .unhealthy || current == .unhealthy {
		return .unhealthy
	}
	if new == .degraded || current == .degraded {
		return .degraded
	}
	if new == .unknown || current == .unknown {
		return .unknown
	}
	return .healthy
}

// ============================================================================
// Query Operations
// ============================================================================

// get_report returns current health report (uses cached results)
pub fn (c &Checker) get_report() HealthReport {
	unsafe { c.mu.rlock() }
	defer { unsafe { c.mu.runlock() } }

	mut components := []ComponentHealth{cap: c.results.len}
	mut overall_status := Status.healthy

	for _, component in c.results {
		components << component
		overall_status = c.aggregate_status(overall_status, component.status)
	}

	return HealthReport{
		status:     overall_status
		timestamp:  time.now().unix_milli()
		components: components
		version:    c.version
	}
}

// get_component_history returns health history for a component
pub fn (c &Checker) get_component_history(name string) []ComponentHealth {
	unsafe { c.mu.rlock() }
	defer { unsafe { c.mu.runlock() } }

	return c.history[name] or { [] }
}

// is_healthy returns true if all components are healthy
pub fn (c &Checker) is_healthy() bool {
	unsafe { c.mu.rlock() }
	defer { unsafe { c.mu.runlock() } }

	for _, component in c.results {
		if component.status == .unhealthy {
			return false
		}
	}
	return true
}

// ============================================================================
// Background Checks
// ============================================================================

// start_background_checks starts periodic health checks
pub fn (mut c Checker) start_background_checks() {
	spawn fn [mut c] () {
		for {
			c.run_checks()
			time.sleep(c.config.check_interval_ms * time.millisecond)
		}
	}()
}

// ============================================================================
// Helper Functions
// ============================================================================

// simple_health_check creates a simple health check from a function that may fail
pub fn simple_health_check(name string, check_fn fn () !) Check {
	return fn [name, check_fn] () ComponentHealth {
		check_fn() or {
			return ComponentHealth{
				name:    name
				status:  .unhealthy
				message: err.msg()
			}
		}

		return ComponentHealth{
			name:    name
			status:  .healthy
			message: 'OK'
		}
	}
}

// threshold_health_check creates a check that fails when value exceeds threshold
pub fn threshold_health_check(name string, get_value fn () f64, threshold f64) Check {
	return fn [name, get_value, threshold] () ComponentHealth {
		value := get_value()

		if value > threshold {
			return ComponentHealth{
				name:    name
				status:  .unhealthy
				message: 'value ${value} exceeds threshold ${threshold}'
			}
		}

		return ComponentHealth{
			name:    name
			status:  .healthy
			message: 'value ${value} within threshold ${threshold}'
		}
	}
}

// ============================================================================
// HTTP Response Format
// ============================================================================

// HTTPResponse for health endpoint
pub struct HTTPResponse {
pub:
	status    string
	timestamp i64
	checks    map[string]map[string]string
}

// to_http_response converts HealthReport to HTTP-friendly format
pub fn (h HealthReport) to_http_response() HTTPResponse {
	mut checks := map[string]map[string]string{}

	for component in h.components {
		checks[component.name] = {
			'status':      component.status.str()
			'message':     component.message
			'last_check':  component.last_check.str()
			'response_ms': component.response_ms.str()
		}
	}

	return HTTPResponse{
		status:    h.status.str()
		timestamp: h.timestamp
		checks:    checks
	}
}

// http_status_code returns appropriate HTTP status code
pub fn (h HealthReport) http_status_code() int {
	return match h.status {
		.healthy   { 200 }
		.degraded  { 200 }
		.unhealthy { 503 }
		.unknown   { 503 }
	}
}
