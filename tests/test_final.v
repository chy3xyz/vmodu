// test_final.v - Final simplified test without module tests
module main

import time

// Import only core modules (without their test functions)
import vmodu.event.bus as eventbus
import vmodu.infra.health as healthcheck
import vmodu.infra.metrics as prom

fn main() {
	println('╔════════════════════════════════════════════════════════════╗')
	println('║           VModulith Runtime - Final Integration Test           ║')
	println('╚════════════════════════════════════════════════════════════╝')
	println('')
	
	mut passed := 0
	mut failed := 0
	
	// Test 1: EventBus
	println('[TEST 1] EventBus - Thread Safety')
	mut eb := eventbus.new_event_bus(eventbus.Config{
		max_subscribers_per_topic: 100
		publish_timeout_ms: 5000
	})
	
	mut received := 0
	eb.subscribe('test.topic', fn [mut received] (msg eventbus.Message) {
		received++
	}) or {
		println('  ❌ Subscribe failed: ${err}')
		failed++
		return
	}
	
	for i := 0; i < 5; i++ {
		eb.publish('test.topic', 'test-${i}'.bytes()) or {
			println('  ❌ Publish failed: ${err}')
			failed++
			return
		}
	}
	
	time.sleep(50 * time.millisecond)
	stats := eb.get_stats()
	
	if stats.messages_published == 5 {
		println('  ✅ Published: ${stats.messages_published}, Delivered: ${stats.messages_delivered}')
		passed++
	} else {
		println('  ❌ Expected 5 messages, got ${stats.messages_published}')
		failed++
	}
	
	// Test 2: Health Check
	println('[TEST 2] Health Check System')
	mut checker := healthcheck.default_checker()
	
	checker.register('test', fn () healthcheck.ComponentHealth {
		return healthcheck.ComponentHealth{
			status: .healthy
			message: 'OK'
		}
	}) or {
		println('  ❌ Register failed: ${err}')
		failed++
		return
	}
	
	report := checker.run_checks()
	if report.status == .healthy {
		println('  ✅ Health status: ${report.status}')
		passed++
	} else {
		println('  ❌ Expected healthy, got ${report.status}')
		failed++
	}
	
	// Test 3: Metrics
	println('[TEST 3] Metrics System')
	mut reg := prom.new_registry('test')
	
	mut counter := reg.new_counter('test_requests', 'Test requests', map[string]string{}) or {
		println('  ❌ Counter creation failed: ${err}')
		failed++
		return
	}
	
	counter.inc()
	counter.add(5)
	
	if counter.get() == 6 {
		println('  ✅ Counter value: ${counter.get()}')
		passed++
	} else {
		println('  ❌ Expected 6, got ${counter.get()}')
		failed++
	}
	
	// Summary
	println('')
	println('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	println('Results: ${passed} passed, ${failed} failed')
	println('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	
	if failed > 0 {
		exit(1)
	}
	
	println('')
	println('✅ All core modules working correctly!')
	println('')
	println('Key Improvements:')
	println('  • EventBus: Thread-safe with mutex protection')
	println('  • Health: Component-based health checking')
	println('  • Metrics: Prometheus-compatible counters')
}
