// adapter_test.v - Unit tests for veb_adapter helpers (no full server)

module veb_adapter

import net.http

struct BindUser {
pub:
	name string
	age  int
}

fn make_ctx(method http.Method, url string, data string, auth string) Context {
	mut header := http.new_header()
	if auth != '' {
		header.set(.authorization, auth)
	}
	mut ctx := Context{
		custom_data: map[string]string{}
	}
	ctx.req = http.Request{
		method: method
		url:    url
		data:   data
		header: header
	}
	ctx.res = http.Response{
		header: http.new_header()
	}
	return ctx
}

fn test_bind_json_ok() {
	mut ctx := make_ctx(.post, '/users', '{"name":"alice","age":30}', '')
	mut user := BindUser{}
	ctx.bind_json[BindUser](mut user) or {
		assert false, 'bind_json failed: ${err}'
		return
	}
	assert user.name == 'alice'
	assert user.age == 30
}

fn test_bind_json_invalid() {
	mut ctx := make_ctx(.post, '/users', '{not-json', '')
	mut user := BindUser{}
	ctx.bind_json[BindUser](mut user) or {
		assert err.msg().contains('invalid JSON')
		return
	}
	assert false, 'expected invalid JSON'
}

fn test_set_get_custom() {
	mut ctx := make_ctx(.get, '/', '', '')
	ctx.set_custom('role', 'admin')
	got := ctx.get_custom('role') or {
		assert false, 'custom key missing'
		return
	}
	assert got == 'admin'
	_ := ctx.get_custom('missing') or { return }
	assert false, 'expected none for missing key'
}

fn test_logging_middleware_continues() {
	mut ctx := make_ctx(.get, '/health', '', '')
	assert logging_middleware(mut ctx) == true
}

fn test_auth_middleware_missing_header() {
	mut ctx := make_ctx(.get, '/secure', '', '')
	ok := auth_middleware(mut ctx)
	assert ok == false
	assert ctx.res.status_code == int(http.Status.unauthorized)
	assert ctx.res.body.contains('missing authorization')
}

fn test_auth_middleware_invalid_format() {
	mut ctx := make_ctx(.get, '/secure', '', 'Token abc')
	ok := auth_middleware(mut ctx)
	assert ok == false
	assert ctx.res.status_code == int(http.Status.unauthorized)
	assert ctx.res.body.contains('invalid authorization format')
}

fn test_auth_middleware_empty_bearer() {
	mut ctx := make_ctx(.get, '/secure', '', 'Bearer ')
	ok := auth_middleware(mut ctx)
	assert ok == false
	assert ctx.res.status_code == int(http.Status.unauthorized)
	assert ctx.res.body.contains('invalid token')
}

fn test_auth_middleware_ok() {
	mut ctx := make_ctx(.get, '/secure', '', 'Bearer real-token')
	ok := auth_middleware(mut ctx)
	assert ok == true
	uid := ctx.get_custom('user_id') or {
		assert false, 'user_id not set'
		return
	}
	assert uid == 'user_123'
}

fn test_cors_middleware_star_allows() {
	mw := cors_middleware(['*'])
	mut ctx := make_ctx(.get, '/api', '', '')
	assert mw(mut ctx) == true
}

fn test_cors_middleware_options_stops() {
	mw := cors_middleware(['*'])
	mut ctx := make_ctx(.options, '/api', '', '')
	assert mw(mut ctx) == false
}

fn test_new_app() {
	app := new_app()
	assert app != unsafe { nil }
}
