module http

import net.http as net_http
import time

fn test_server_health_route() {
	mut server := new_server(ServerConfig{
		host: '127.0.0.1'
		port: 0
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
	res := net_http.get(url) or {
		assert false, 'GET failed: ${err}'
		return
	}
	assert res.status_code == 200
	assert res.body.contains('ok')
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
