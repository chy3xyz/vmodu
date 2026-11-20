// main.v - VModu Runtime Entry Point
module main

import time
import vmodu.core { new_container }
import vmodu.infra.http
import vmodu.infra.metrics

fn main() {
	println('╔════════════════════════════════════════════════════════════╗')
	println('║                 VModu Runtime v0.1.0                       ║')
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
	exporter := metrics.new_exporter(registry)

	mut server := http.new_server(http.ServerConfig{
		host: '0.0.0.0'
		port: 8080
	})

	server.get('/health', health_handler)
	server.get('/api/health', health_handler)
	server.get('/metrics', fn [exporter, mut req_counter] (ctx http.Context) !http.Response {
		req_counter.inc()
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

	listen_addr := 'http://${server.host}:${server.port}'
	println('')
	println('✅ VModu is running!')
	println('   Listening: ${listen_addr}')
	println('   Health:    ${listen_addr}/health')
	println('   Metrics:   ${listen_addr}/metrics')
	println('   Press Ctrl+C to stop')
	println('')

	for server.is_running() {
		time.sleep(500 * time.millisecond)
	}

	server.stop() or {}
	container.stop() or {}
}

fn health_handler(_ http.Context) !http.Response {
	mut resp := http.new_response()
	resp.status_code = 200
	resp.headers['Content-Type'] = 'application/json'
	resp.body = '{"status":"ok"}'
	return resp
}
