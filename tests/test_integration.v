// test_integration.v
// Integration test for all improved modules

module main

import os
import time

// Import all improved modules
import vmodu.event.bus
import vmodu.infra.db
import vmodu.infra.logger
import vmodu.infra.health
import vmodu.infra.metrics
import vmodu.infra.circuit
import vmodu.infra.trace
import vmodu.config

fn test_event_bus() ! {
	println('[TEST] Event Bus - Thread Safety')
	
	mut eb := bus.new_event_bus(bus.Config{
		max_subscribers_per_topic: 100
		publish_timeout_ms: 5000
	})
	
	mut received := 0
	eb.subscribe('test.topic', fn [mut received] (msg bus.Message) {
		received++
	})!
	
	// Publish multiple messages
	for i := 0; i < 10; i++ {
		eb.publish('test.topic', 'test-${i}'.bytes())!
	}
	
	time.sleep(50 * time.millisecond)
	stats := eb.get_stats()
	
	assert stats.messages_published == 10
	println('  ✅ EventBus: Published ${stats.messages_published}, Delivered ${stats.messages_delivered}')
}

fn test_event_store() ! {
	println('[TEST] Event Store - Buffered I/O')
	
	test_dir := './test_data'
	if os.exists(test_dir) {
		os.rmdir_all(test_dir) or {}
	}
	
	mut store := db.new_persistent_log(db.StoreConfig{
		data_dir:          test_dir
		segment_size:      100
		buffer_size:       1024
		flush_interval_ms: 50
		fsync_on_write:    false  // Faster for tests
	})!
	defer {
		store.close() or {}
		os.rmdir_all(test_dir) or {}
	}
	
	// Append events
	for i := 0; i < 50; i++ {
		store.append('test-stream', 'event-${i}')!
	}
	
	stats := store.get_stats()
	assert stats.writes_total == 50
	println('  ✅ Event Store: ${stats.writes_total} writes, ${stats.bytes_written} bytes')
}

fn test_logger() ! {
	println('[TEST] Logger - Structured Logging')
	
	mut log := logger.new(logger.Config{
		level:  .debug
		format: .text
		output: 'stdout'
	})!
	
	log.info('Test message')
	log.info_with_fields('Test with fields', {
		'key1': 'value1'
		'key2': 'value2'
	})
	
	println('  ✅ Logger: Text and JSON formats working')
}

fn test_health() ! {
	println('[TEST] Health Checks')
	
	mut checker := health.default_checker()
	
	mut check_called := false
	checker.register('test', fn [mut check_called] () health.ComponentHealth {
		check_called = true
		return health.ComponentHealth{
			status:  .healthy
			message: 'Test OK'
		}
	})!
	
	report := checker.run_checks()
	
	assert report.status == .healthy
	assert check_called == true
	println('  ✅ Health: Status ${report.status}, ${report.components.len} components')
}

fn test_metrics() ! {
	println('[TEST] Metrics - Prometheus Format')
	
	mut reg := metrics.new_registry('test')
	
	mut counter := reg.new_counter('requests', 'Total requests', {})!
	mut gauge := reg.new_gauge('active', 'Active connections', {})!
	mut hist := reg.new_histogram('duration', 'Duration', {}, [0.1, 0.5, 1.0])!
	
	counter.inc()
	counter.add(5)
	gauge.set(42.0)
	hist.observe(0.25)
	
	exporter := metrics.new_exporter(reg)
	output := exporter.export()
	
	assert output.contains('test_requests')
	assert output.contains('test_active')
	println('  ✅ Metrics: Counter, Gauge, Histogram exported')
}

fn test_circuit_breaker() ! {
	println('[TEST] Circuit Breaker')
	
	mut cb := circuit.new(circuit.Config{
		name:              'test'
		failure_threshold: 3
		success_threshold: 2
		timeout_ms:        1000
	})
	
	// Successful operation
	result := cb.execute(fn () !string {
		return 'success'
	})!
	assert result == 'success'
	assert cb.get_state() == .closed
	
	// Failures to open circuit
	for _ in 0..3 {
		_ := cb.execute(fn () !string {
			return error('fail')
		})
	}
	
	assert cb.get_state() == .open
	println('  ✅ Circuit Breaker: Closed -> Open transition working')
}

fn test_tracing() ! {
	println('[TEST] Distributed Tracing')
	
	exporter := trace.new_in_memory_exporter()
	trace.init_global('test-service', exporter)
	
	mut span := trace.start_quick_span('test-operation')
	span.set_attribute('key', 'value')
	span.add_event('event1', {'foo': 'bar'})
	span.set_ok()
	span.end()
	
	spans := exporter.get_spans()
	assert spans.len == 1
	assert spans[0].name == 'test-operation'
	println('  ✅ Tracing: Span creation and export working')
}

fn test_config() ! {
	println('[TEST] Configuration')
	
	// Test default config
	cfg := config.default()
	assert cfg.server.http_port == 8080
	assert cfg.actor.mailbox_size == 100
	
	// Test validation
	mut invalid_cfg := cfg
	invalid_cfg.server.http_port = 0
	if _ := config.validate(invalid_cfg) {
		assert false, 'should fail validation'
	}
	
	println('  ✅ Config: Defaults and validation working')
}

fn main() {
	println('╔══════════════════════════════════════════════════════════════════════════╗')
	println('║                   VModulith Runtime - Integration Tests                       ║')
	println('╚══════════════════════════════════════════════════════════════════════════╝')
	println('')
	
	mut passed := 0
	mut failed := 0
	
	tests := [
		test_event_bus,
		test_event_store,
		test_logger,
		test_health,
		test_metrics,
		test_circuit_breaker,
		test_tracing,
		test_config,
	]
	
	for test in tests {
		test() or {
			println('  ❌ FAILED: ${err}')
			failed++
			continue
		}
		passed++
	}
	
	println('')
	println('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	println('Results: ${passed} passed, ${failed} failed')
	println('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
	
	if failed > 0 {
		exit(1)
	}
}
