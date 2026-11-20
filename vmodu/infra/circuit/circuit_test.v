// circuit_test.v - Unit tests for Circuit Breaker pattern

module circuit

import time

// test_new_circuit_breaker tests creation
fn test_new_circuit_breaker() {
	config := Config{
		name:              'test-cb'
		failure_threshold: 5
		success_threshold: 3
		timeout_ms:        1000
		half_open_max_calls: 3
	}
	
	cb := new(config)
	
	assert cb.config.name == 'test-cb'
	assert cb.config.failure_threshold == 5
	assert cb.config.success_threshold == 3
	assert cb.config.timeout_ms == 1000
	assert cb.state == .closed
	assert cb.failures == 0
}

// test_default_circuit_breaker tests defaults
fn test_default_circuit_breaker() {
	cb := default('my-service')
	
	assert cb.config.name == 'my-service'
	assert cb.config.failure_threshold == 5
	assert cb.config.success_threshold == 3
	assert cb.config.timeout_ms == 60000
	assert cb.state == .closed
}

// test_closed_state_allows_requests tests closed state allows requests
fn test_closed_state_allows_requests() {
	mut cb := default('test')
	
	assert cb.get_state() == .closed
	assert cb.allow() == true
}

// test_record_success_in_closed tests success counting in closed state
fn test_record_success_in_closed() {
	mut cb := default('test')
	
	cb.record_success()
	cb.record_success()
	cb.record_success()
	
	assert cb.get_state() == .closed
}

// test_failure_threshold_opens tests failures open the circuit
fn test_failure_threshold_opens() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 3
		success_threshold: 2
		timeout_ms:        1000
	})
	
	// Record failures up to threshold
	cb.record_failure()
	assert cb.get_state() == .closed
	
	cb.record_failure()
	assert cb.get_state() == .closed
	
	cb.record_failure()
	assert cb.get_state() == .open
}

// test_open_state_rejects tests open state rejects requests
fn test_open_state_rejects() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 1
		timeout_ms:        1000
	})
	
	// Open the circuit
	cb.record_failure()
	assert cb.get_state() == .open
	
	// Should reject requests
	assert cb.allow() == false
}

// test_half_open_after_timeout tests transition to half-open after timeout
fn test_half_open_after_timeout() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 1
		timeout_ms:        50  // Short timeout for testing
	})
	
	// Open the circuit
	cb.record_failure()
	assert cb.get_state() == .open
	assert cb.allow() == false
	
	// Wait for timeout
	time.sleep(60 * time.millisecond)
	
	// Should now allow (transitioning to half-open)
	assert cb.allow() == true
	assert cb.get_state() == .half_open
}

// test_half_open_success_closes tests success in half-open closes circuit
fn test_half_open_success_closes() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 1
		success_threshold: 2
		timeout_ms:        50
	})
	
	// Open and transition to half-open
	cb.record_failure()
	time.sleep(60 * time.millisecond)
	cb.allow() // Trigger transition
	
	assert cb.get_state() == .half_open
	
	// Successes should close circuit
	cb.record_success()
	assert cb.get_state() == .half_open  // Still half-open after 1 success
	
	cb.record_success()
	assert cb.get_state() == .closed  // Closed after success_threshold
}

// test_half_open_failure_reopens tests failure in half-open reopens circuit
fn test_half_open_failure_reopens() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 1
		success_threshold: 3
		timeout_ms:        50
	})
	
	// Open and transition to half-open
	cb.record_failure()
	time.sleep(60 * time.millisecond)
	cb.allow()
	
	assert cb.get_state() == .half_open
	
	// Single failure should reopen
	cb.record_failure()
	assert cb.get_state() == .open
}

// test_reset_manual tests manual reset
fn test_reset_manual() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 1
		timeout_ms:        5000
	})
	
	// Open the circuit
	cb.record_failure()
	assert cb.get_state() == .open
	
	// Reset manually
	cb.reset()
	
	assert cb.get_state() == .closed
	assert cb.allow() == true
}

// test_execute_success tests execute with successful operation
fn test_execute_success() {
	mut cb := default('test')
	
	result := cb.execute(fn () !string {
		return 'success'
	}) or {
		assert false, 'should succeed: ${err}'
		return
	}
	
	assert result == 'success'
	assert cb.get_state() == .closed
}

// test_execute_failure tests execute with failing operation
fn test_execute_failure() {
	mut cb := default('test')
	
	cb.execute(fn () !string {
		return error('boom')
	}) or {
		assert err.msg() == 'boom'
		return
	}
	
	assert false, 'should have failed'
}

// test_execute_opens_circuit tests execute opens circuit after failures
fn test_execute_opens_circuit() {
	mut cb := new(Config{
		name:              'test'
		failure_threshold: 2
		timeout_ms:        5000
	})
	
	// First failure
	cb.execute(fn () !string {
		return error('fail1')
	}) or {}
	
	assert cb.get_state() == .closed  // Still closed after 1
	
	// Second failure
	cb.execute(fn () !string {
		return error('fail2')
	}) or {}
	
	assert cb.get_state() == .open  // Open after threshold
	
	// Next execute should fail fast
	cb.execute(fn () !string {
		return 'should not reach here'
	}) or {
		assert err.msg().contains('circuit breaker open')
		return
	}
	
	assert false, 'should have failed with circuit open'
}

// test_state_string tests state string representation
fn test_state_string() {
	assert State.closed.str() == 'closed'
	assert State.open.str() == 'open'
	assert State.half_open.str() == 'half-open'
}

// test_stats tests getting stats
fn test_stats() {
	mut cb := new(Config{
		name: 'test'
		failure_threshold: 1
	})
	
	// Initial state
	stats1 := cb.get_stats()
	assert stats1.state == .closed
	assert stats1.failures == 0
	
	// After failure (threshold is 1, so should open)
	cb.record_failure()
	stats2 := cb.get_stats()
	assert stats2.state == .open
}

// test_manager_creation tests creating manager
fn test_manager_creation() {
	mgr := new_manager(Config{
		failure_threshold: 10
		timeout_ms:        5000
	})
	
	assert mgr.breakers.len == 0
	assert mgr.config.failure_threshold == 10
}

// test_manager_get_or_create tests getting or creating breakers
fn test_manager_get_or_create() {
	mut mgr := new_manager(Config{})
	
	cb1 := mgr.get_or_create('service-a')
	cb2 := mgr.get_or_create('service-a')
	cb3 := mgr.get_or_create('service-b')
	
	// Same name should return same instance
	assert cb1 == cb2
	assert cb1 != cb3
	
	assert mgr.breakers.len == 2
}

// test_manager_get_existing tests getting existing breaker
fn test_manager_get_existing() {
	mut mgr := new_manager(Config{})
	
	mgr.get_or_create('existing')
	
	cb := mgr.get('existing') or {
		assert false, 'should find existing'
		return
	}
	
	assert cb.config.name == 'existing'
}

// test_manager_get_nonexistent tests getting non-existent breaker
fn test_manager_get_nonexistent() {
	mut mgr := new_manager(Config{})
	
	mgr.get('nonexistent') or {
		// Expected to fail
		return
	}
	
	assert false, 'should fail for non-existent'
}

// test_manager_remove tests removing breaker
fn test_manager_remove() {
	mut mgr := new_manager(Config{})
	
	mgr.get_or_create('to-remove')
	assert mgr.breakers.len == 1
	
	mgr.remove('to-remove')
	assert mgr.breakers.len == 0
}

// test_manager_get_all tests getting all breakers
fn test_manager_get_all() {
	mut mgr := new_manager(Config{})
	
	mgr.get_or_create('a')
	mgr.get_or_create('b')
	mgr.get_or_create('c')
	
	all := mgr.get_all()
	assert all.len == 3
}
