// adapter.v - veb Adapter for VModulith (V 0.5.2+)
// Helpers for modern attribute-based veb apps: Context wrappers, JSON bind,
// and Middleware[Context] factories.

module veb_adapter

import veb
import json2

// Context wraps veb.Context with VModulith convenience fields.
pub struct Context {
	veb.Context
pub mut:
	custom_data map[string]string
}

// App is a minimal veb application shell with middleware support.
pub struct App {
	veb.Middleware[Context]
}

// Result is the result type alias.
pub type Result = veb.Result

// new_app creates a new veb adapter app.
pub fn new_app() &App {
	return &App{}
}

// run starts the server using the current veb API.
pub fn (mut app App) run(port int) {
	veb.run[App, Context](mut app, port)
}

// bind_json binds JSON body to struct.
pub fn (ctx &Context) bind_json[T](mut dest T) ! {
	dest = json2.decode[T](ctx.req.data) or {
		return error('invalid JSON: ${err}')
	}
}

// set_custom stores a custom string value on the context.
pub fn (mut ctx Context) set_custom(key string, value string) {
	ctx.custom_data[key] = value
}

// get_custom reads a custom string value from the context.
pub fn (ctx &Context) get_custom(key string) ?string {
	return ctx.custom_data[key] or { return none }
}

// logging_middleware logs method + URL; return true to continue.
pub fn logging_middleware(mut ctx Context) bool {
	println('[veb] ${ctx.req.method} ${ctx.req.url}')
	return true
}

// cors_middleware creates a CORS before-handler for allowed origins.
pub fn cors_middleware(allowed_origins []string) fn (mut Context) bool {
	return fn [allowed_origins] (mut ctx Context) bool {
		origin := ctx.get_custom_header('Origin') or { '' }

		mut allowed := false
		if allowed_origins.len == 0 || allowed_origins[0] == '*' {
			allowed = true
		} else {
			for o in allowed_origins {
				if o == origin {
					allowed = true
					break
				}
			}
		}

		if allowed {
			allow_origin := if allowed_origins.len == 0 || allowed_origins[0] == '*' {
				'*'
			} else {
				origin
			}
			ctx.set_header(.access_control_allow_origin, allow_origin)
			ctx.set_header(.access_control_allow_methods, 'GET, POST, PUT, DELETE, PATCH, OPTIONS')
			ctx.set_header(.access_control_allow_headers, 'Content-Type, Authorization')
		}

		if ctx.req.method == .options {
			return false
		}
		return true
	}
}

// auth_middleware requires a non-empty Bearer token.
pub fn auth_middleware(mut ctx Context) bool {
	auth_header := ctx.get_header(.authorization) or { '' }

	if auth_header == '' {
		ctx.res.set_status(.unauthorized)
		ctx.res.body = json2.encode({
			'error':   'unauthorized'
			'message': 'missing authorization header'
		}, escape_unicode: true)
		return false
	}

	if !auth_header.starts_with('Bearer ') {
		ctx.res.set_status(.unauthorized)
		ctx.res.body = json2.encode({
			'error':   'unauthorized'
			'message': 'invalid authorization format'
		}, escape_unicode: true)
		return false
	}

	token := auth_header[7..]
	if token == '' {
		ctx.res.set_status(.unauthorized)
		ctx.res.body = json2.encode({
			'error':   'unauthorized'
			'message': 'invalid token'
		}, escape_unicode: true)
		return false
	}

	ctx.set_custom('user_id', 'user_123')
	return true
}
