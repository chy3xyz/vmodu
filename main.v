// main.v - VModu Runtime Entry Point
module main

import os
import time
import json2
import vmodu.core { new_container }
import vmodu.config { load_runtime_config }
import vmodu.infra.http
import vmodu.infra.metrics
import vmodu.infra.health
import vmodu.infra.trace

struct ShutdownFlag {
mut:
	requested bool
}

fn main() {
	println('╔════════════════════════════════════════════════════════════╗')
	println('║                 VModu Runtime v0.2.0                       ║')
	println('║              Modular Backend Framework                     ║')
	println('╚════════════════════════════════════════════════════════════╝')
	println('')

	mut container := new_container()
	container.start() or {
		eprintln('Failed to start container: ${err}')
		exit(1)
	}

	mut registry := metrics.new_registry('vmodu')
	mut req_counter := registry.new_counter('http_requests_total', 'HTTP requests', {}) or {
		panic(err)
	}
	mut rate_limited_gauge := registry.new_gauge('http_rate_limited_total', 'HTTP 429 responses', {}) or {
		panic(err)
	}
	exporter := metrics.new_exporter(registry)

	mut checker := health.default_checker()
	checker.register('process', fn () health.ComponentHealth {
		return health.ComponentHealth{
			name:    'process'
			status:  .healthy
			message: 'running'
		}
	}) or {}
	checker.register('http', fn () health.ComponentHealth {
		return health.ComponentHealth{
			name:    'http'
			status:  .healthy
			message: 'listener up'
		}
	}) or {}

	rt := load_runtime_config()
	mut server := http.new_server(http.ServerConfig{
		host:                rt.http_host
		port:                rt.http_port
		max_connections:     rt.max_connections
		rate_limit_rps:      rt.rate_limit_rps
		rate_limit_burst:    rt.rate_limit_burst
		rate_limit_per_ip:   rt.rate_limit_per_ip
		ip_rate_limit_rps:   rt.ip_rate_limit_rps
		ip_rate_limit_burst: rt.ip_rate_limit_burst
		access_log:          rt.access_log
	})

	if rt.trace_enabled {
		server.use(http.trace_middleware(trace.new_tracer('vmodu', trace.new_console_exporter(false))))
	} else {
		server.use(http.trace_middleware(trace.new_tracer('vmodu', trace.new_noop_exporter())))
	}

	server.get('/health', health_handler)
	server.get('/api/health', health_handler)
	server.get('/health/deep', fn [mut checker] (ctx http.Context) !http.Response {
		report := checker.run_checks()
		http_body := report.to_http_response()
		mut resp := http.new_response()
		resp.status_code = report.http_status_code()
		resp.headers['Content-Type'] = 'application/json'
		resp.body = json2.encode(http_body, escape_unicode: true)
		return resp
	})
	server.get('/metrics', fn [exporter, mut req_counter, mut rate_limited_gauge, mut server] (ctx http.Context) !http.Response {
		req_counter.inc()
		stats := server.get_stats()
		rate_limited_gauge.set(f64(stats.rate_limited_total))
		mut resp := http.new_response()
		resp.status_code = 200
		resp.headers['Content-Type'] = 'text/plain; version=0.0.4'
		resp.body = exporter.export()
		return resp
	})

	server.start() or {
		eprintln('Failed to start HTTP server: ${err}')
		exit(1)
	}

	mut shutdown := &ShutdownFlag{}
	os.signal_opt(.int, fn [mut shutdown] (_ os.Signal) {
		shutdown.requested = true
	}) or {
		eprintln('Warning: failed to register SIGINT handler: ${err}')
	}
	os.signal_opt(.term, fn [mut shutdown] (_ os.Signal) {
		shutdown.requested = true
	}) or {
		eprintln('Warning: failed to register SIGTERM handler: ${err}')
	}

	listen_addr := 'http://${server.host}:${server.port}'
	println('')
	println('✅ VModu is running!')
	println('   Listening: ${listen_addr}')
	println('   Health:    ${listen_addr}/health')
	println('   Deep:      ${listen_addr}/health/deep')
	println('   Metrics:   ${listen_addr}/metrics')
	println('   Press Ctrl+C to stop')
	println('')

	for server.is_running() {
		if shutdown.requested {
			break
		}
		time.sleep(500 * time.millisecond)
	}

	println('Shutting down...')
	server.stop() or {}
	container.stop() or {}
	println('Goodbye.')
}

fn health_handler(_ http.Context) !http.Response {
	mut resp := http.new_response()
	resp.status_code = 200
	resp.headers['Content-Type'] = 'application/json'
	resp.body = '{"status":"ok"}'
	return resp
}
