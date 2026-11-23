module http

import net.http as net_http
import time

fn test_server_health_route() {
	mut server := new_server(ServerConfig{
		host:       '127.0.0.1'
		port:       0
		access_log: false
	})

	server.get('/health', fn (ctx Context) !Response {
		mut resp := new_response()
		resp.status_code = 200
		resp.headers['Content-Type'] = 'application/json'
		resp.body = '{"status":"ok"}'
		return resp
	})

	server.start() or {
		assert false, 'start failed: ${err}'
		return
	}
	defer {
		server.stop() or {}
	}

	time.sleep(100 * time.millisecond)

	url := 'http://127.0.0.1:${server.port}/health'
	mut req := net_http.new_request(.get, url, '')
	req.add_custom_header('X-Request-ID', 'test-req-42') or {
		assert false, 'add header: ${err}'
		return
	}
	res := req.do() or {
		assert false, 'GET failed: ${err}'
		return
	}
	assert res.status_code == 200
	assert res.body.contains('ok')
	rid := res.header.get_custom('X-Request-ID') or { '' }
	assert rid == 'test-req-42'
}

fn test_server_404() {
	mut server := new_server(ServerConfig{
		host: '127.0.0.1'
		port: 0
	})
	server.start() or {
		assert false, 'start failed: ${err}'
		return
	}
	defer {
		server.stop() or {}
	}

	time.sleep(100 * time.millisecond)

	url := 'http://127.0.0.1:${server.port}/missing'
	res := net_http.get(url) or {
		assert false, 'GET failed: ${err}'
		return
	}
	assert res.status_code == 404
}

fn test_match_path_params() {
	params := match_path('/users/:id', '/users/42') or {
		assert false, 'expected match'
		return
	}
	assert params['id'] == '42'
}

fn test_rate_limit_rejects_second_request() {
	// Token-bucket: rps=1, burst=1 → first GET ok, immediate second GET → 429
	mut server := new_server(ServerConfig{
		host:             '127.0.0.1'
		port:             0
		rate_limit_rps:   1
		rate_limit_burst: 1
	})

	server.get('/limited', fn (ctx Context) !Response {
		mut resp := new_response()
		resp.status_code = 200
		resp.body = 'ok'
		return resp
	})

	server.start() or {
		assert false, 'start failed: ${err}'
		return
	}
	defer {
		server.stop() or {}
	}

	time.sleep(100 * time.millisecond)
	url := 'http://127.0.0.1:${server.port}/limited'

	res1 := net_http.get(url) or {
		assert false, 'first GET failed: ${err}'
		return
	}
	assert res1.status_code == 200, 'first request should succeed'

	res2 := net_http.get(url) or {
		assert false, 'second GET failed: ${err}'
		return
	}
	assert res2.status_code == 429, 'second request should be rate-limited'
	assert res2.body.contains('Too Many Requests')
	stats := server.get_stats()
	assert stats.rate_limited_total >= 1
}

fn test_rate_limiter_unit() {
	mut lim := new_rate_limiter(1, 1)
	assert lim.allow() == true
	assert lim.allow() == false
	// Disabled limiter always allows
	mut off := new_rate_limiter(0, 0)
	assert off.allow() == true
	assert off.allow() == true
}

fn test_ip_rate_limiter_unit() {
	mut ip := new_ip_rate_limiter(1, 1, 100)
	assert ip.allow('1.2.3.4') == true
	assert ip.allow('1.2.3.4') == false
	assert ip.allow('5.6.7.8') == true // different IP has its own bucket
}

fn test_per_ip_rate_limit_rejects() {
	mut server := new_server(ServerConfig{
		host:               '127.0.0.1'
		port:               0
		rate_limit_rps:     0 // global off
		rate_limit_per_ip:  true
		ip_rate_limit_rps:  1
		ip_rate_limit_burst: 1
	})
	server.get('/ip', fn (ctx Context) !Response {
		mut resp := new_response()
		resp.status_code = 200
		resp.body = 'ok'
		return resp
	})
	server.start() or {
		assert false, 'start: ${err}'
		return
	}
	defer {
		server.stop() or {}
	}
	time.sleep(100 * time.millisecond)
	url := 'http://127.0.0.1:${server.port}/ip'
	r1 := net_http.get(url) or {
		assert false, '${err}'
		return
	}
	assert r1.status_code == 200
	r2 := net_http.get(url) or {
		assert false, '${err}'
		return
	}
	assert r2.status_code == 429
	assert server.get_stats().rate_limited_total >= 1
}

fn test_max_connections_rejects() {
	mut server := new_server(ServerConfig{
		host:            '127.0.0.1'
		port:            0
		max_connections: 1
		stop_timeout_ms: 2000
	})

	server.get('/slow', fn (ctx Context) !Response {
		time.sleep(500 * time.millisecond)
		mut resp := new_response()
		resp.status_code = 200
		resp.body = 'ok'
		return resp
	})

	server.start() or {
		assert false, 'start failed: ${err}'
		return
	}
	defer {
		server.stop() or {}
	}

	time.sleep(100 * time.millisecond)
	url := 'http://127.0.0.1:${server.port}/slow'

	spawn fn [url] () {
		net_http.get(url) or {}
	}()

	mut saw_active := false
	for _ in 0 .. 50 {
		if server.get_stats().requests_active >= 1 {
			saw_active = true
			break
		}
		time.sleep(20 * time.millisecond)
	}
	assert saw_active, 'expected first request to become active'

	res := net_http.get(url) or {
		// connection failure treated as rejection
		return
	}
	assert res.status_code == 503
}
