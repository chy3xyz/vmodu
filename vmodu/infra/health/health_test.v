// health_test.v - Unit tests for Health Check system

module health

import time

// test_new_checker tests creating a new health checker
fn test_new_checker() {
	config := CheckerConfig{
		check_interval_ms: 30000
		history_size:      10
		strict_mode:       false
	}
	
	checker := new_checker(config)
	
	assert checker.config.check_interval_ms == 30000
	assert checker.config.history_size == 10
	assert checker.checks.len == 0
	assert checker.results.len == 0
	assert checker.version == 'v3.0.0'
}

// test_default_checker tests the default checker configuration
fn test_default_checker() {
	checker := default_checker()
	
	assert checker.config.check_interval_ms == 30000
	assert checker.config.history_size == 10
}

// test_register_check tests registering a health check
fn test_register_check() {
	mut checker := default_checker()
	
	checker.register('test.check', fn () ComponentHealth {
		return ComponentHealth{
			status:  .healthy
			message: 'OK'
		}
	}) or {
		assert false, 'register should succeed: ${err}'
		return
	}
	
	assert checker.checks.len == 1
}

// test_register_duplicate tests registering duplicate check fails
fn test_register_duplicate() {
	mut checker := default_checker()
	
	checker.register('duplicate', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or { assert false }
	
	checker.register('duplicate', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or {
		assert err.msg().contains('already registered')
		return
	}
	
	assert false, 'should have failed for duplicate registration'
}

// test_unregister tests removing a check
fn test_unregister() {
	mut checker := default_checker()
	
	checker.register('to_remove', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or { assert false }
	
	assert checker.checks.len == 1
	
	checker.unregister('to_remove')
	
	assert checker.checks.len == 0
}

// test_run_checks tests running all registered checks
fn test_run_checks() {
	mut checker := default_checker()
	
	checker.register('check1', fn () ComponentHealth {
		return ComponentHealth{
			status:  .healthy
			message: 'check1 ok'
		}
	}) or { assert false }
	
	checker.register('check2', fn () ComponentHealth {
		return ComponentHealth{
			status:  .healthy
			message: 'check2 ok'
		}
	}) or { assert false }
	
	report := checker.run_checks()
	
	assert report.status == .healthy
	assert report.components.len == 2
}

// test_run_checks_unhealthy tests unhealthy component detection
fn test_run_checks_unhealthy() {
	mut checker := default_checker()
	
	checker.register('healthy_check', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or { assert false }
	
	checker.register('unhealthy_check', fn () ComponentHealth {
		return ComponentHealth{status: .unhealthy}
	}) or { assert false }
	
	report := checker.run_checks()
	
	assert report.status == .unhealthy
}

// test_run_checks_degraded tests degraded component handling
fn test_run_checks_degraded() {
	mut checker := default_checker()
	
	checker.register('healthy_check', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or { assert false }
	
	checker.register('degraded_check', fn () ComponentHealth {
		return ComponentHealth{status: .degraded}
	}) or { assert false }
	
	report := checker.run_checks()
	
	assert report.status == .degraded
}

// test_get_report tests retrieving cached report
fn test_get_report() {
	mut checker := default_checker()
	
	// No checks registered
	report1 := checker.get_report()
	assert report1.status == .healthy
	
	// Register and run checks
	checker.register('test', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or { assert false }
	
	checker.run_checks()
	
	report2 := checker.get_report()
	assert report2.components.len == 1
}

// test_is_healthy tests the convenience method
fn test_is_healthy() {
	mut checker := default_checker()
	
	// No checks = healthy
	assert checker.is_healthy() == true
	
	// All healthy = healthy
	checker.register('healthy', fn () ComponentHealth {
		return ComponentHealth{status: .healthy}
	}) or { assert false }
	checker.run_checks()
	assert checker.is_healthy() == true
	
	// One unhealthy = not healthy
	checker.unregister('healthy')
	checker.register('unhealthy', fn () ComponentHealth {
		return ComponentHealth{status: .unhealthy}
	}) or { assert false }
	checker.run_checks()
	assert checker.is_healthy() == false
}

// test_status_enum tests Status enum values
fn test_status_enum() {
	assert Status.unknown.str() == 'unknown'
	assert Status.healthy.str() == 'healthy'
	assert Status.degraded.str() == 'degraded'
	assert Status.unhealthy.str() == 'unhealthy'
}

// test_http_status_code tests HTTP status code mapping
fn test_http_status_code() {
	healthy_report := HealthReport{status: .healthy}
	assert healthy_report.http_status_code() == 200
	
	degraded_report := HealthReport{status: .degraded}
	assert degraded_report.http_status_code() == 200
	
	unhealthy_report := HealthReport{status: .unhealthy}
	assert unhealthy_report.http_status_code() == 503
	
	unknown_report := HealthReport{status: .unknown}
	assert unknown_report.http_status_code() == 503
}

// test_checker_config_defaults tests config defaults
fn test_checker_config_defaults() {
	config := CheckerConfig{}
	
	assert config.check_interval_ms == 30000
	assert config.history_size == 10
}

// test_component_health_structure tests ComponentHealth fields
fn test_component_health_structure() {
	ch := ComponentHealth{
		name:        'test'
		status:      .healthy
		message:     'all good'
		last_check:  time.now().unix_milli()
		response_ms: 42
	}
	
	assert ch.name == 'test'
	assert ch.status == .healthy
	assert ch.message == 'all good'
	assert ch.response_ms == 42
}

// test_simple_health_check_helper tests simple_health_check exists
fn test_simple_health_check_helper() {
	// Just verify the function exists and returns correct type
	check := simple_health_check('test', fn () ! {
		return
	})
	
	// Function should be callable
	result := check()
	assert result.status == .healthy
}

// test_simple_health_check_error tests simple check with error
fn test_simple_health_check_error() {
	check := simple_health_check('failing', fn () ! {
		return error('something broke')
	})
	
	result := check()
	assert result.status == .unhealthy
}

// test_threshold_health_check tests threshold helper
fn test_threshold_health_check() {
	// Test with value below threshold (healthy)
	check1 := threshold_health_check('threshold', fn () f64 {
		return 50.0
	}, 100.0)
	
	result1 := check1()
	assert result1.status == .healthy
	
	// Test with value above threshold (unhealthy)
	check2 := threshold_health_check('threshold', fn () f64 {
		return 150.0
	}, 100.0)
	
	result2 := check2()
	assert result2.status == .unhealthy
}

// test_health_report_conversion tests HTTP response conversion
fn test_health_report_conversion() {
	report := HealthReport{
		status:    .healthy
		timestamp: time.now().unix_milli()
		components: [
			ComponentHealth{
				name:   'comp1'
				status: .healthy
			}
		]
		version: 'v3.0.0'
	}
	
	resp := report.to_http_response()
	
	assert resp.status == 'healthy'
	assert resp.timestamp == report.timestamp
	assert resp.checks.len == 1
}
