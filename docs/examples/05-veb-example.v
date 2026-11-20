// 05-veb-example.v - veb Web Framework Example
// Demonstrates using veb for building web applications

module main

import veb
import net.http
import json2

// User represents a user
pub struct User {
mut:
	id    int    @[json: 'id']
	name  string @[json: 'name']
	email string @[json: 'email']
}

// App is the main application
pub struct App {
	veb.Controller
	veb.StaticHandler
mut:
	users []User
}

// new_app creates a new app
pub fn new_app() &App {
	return &App{
		users: [
			User{ id: 1, name: 'Alice', email: 'alice@example.com' }
			User{ id: 2, name: 'Bob', email: 'bob@example.com' },
		]
	}
}

// before_request middleware
pub fn (mut app App) before_request(mut ctx veb.Context) bool {
	println('[${ctx.req.method}] ${ctx.req.url}')
	return true
}

// index handles GET /
pub fn (mut app App) index(mut ctx veb.Context) veb.Result {
	return ctx.html('<h1>Welcome to VModulith with veb!</h1>
<p>Try these endpoints:</p>
<ul>
<li>GET /api/users</li>
<li>GET /api/users/1</li>
<li>POST /api/users</li>
</ul>')
}

// get_users handles GET /api/users
@['/api/users']
pub fn (mut app App) get_users(mut ctx veb.Context) veb.Result {
	return ctx.json(app.users)
}

// get_user handles GET /api/users/:id
@['/api/users/:id']
pub fn (mut app App) get_user(mut ctx veb.Context) veb.Result {
	id_str := ctx.param('id')
	id := id_str.int()

	for user in app.users {
		if user.id == id {
			return ctx.json(user)
		}
	}

	ctx.res.status_code = http.Status.not_found
	return ctx.json({
		'error': 'user not found'
	})
}

// create_user handles POST /api/users
@['/api/users'; post]
pub fn (mut app App) create_user(mut ctx veb.Context) veb.Result {
	// Parse JSON body
	mut user := json2.decode[User](ctx.req.data) or {
		ctx.res.set_status(.bad_request)
		return ctx.json({
			'error': 'invalid JSON'
		})
	}

	// Generate ID
	user.id = app.users.len + 1
	app.users << user

	ctx.res.status_code = http.Status.created
	return ctx.json(user)
}

// update_user handles PUT /api/users/:id
@['/api/users/:id'; put]
pub fn (mut app App) update_user(mut ctx veb.Context) veb.Result {
	id_str := ctx.param('id')
	id := id_str.int()

	// Parse JSON body
	mut updated := json2.decode[User](ctx.req.data) or {
		ctx.res.set_status(.bad_request)
		return ctx.json({
			'error': 'invalid JSON'
		})
	}

	// Find and update user
	for i, user in app.users {
		if user.id == id {
			app.users[i] = updated
			return ctx.json(updated)
		}
	}

	ctx.res.status_code = http.Status.not_found
	return ctx.json({
		'error': 'user not found'
	})
}

// delete_user handles DELETE /api/users/:id
@['/api/users/:id'; delete]
pub fn (mut app App) delete_user(mut ctx veb.Context) veb.Result {
	id_str := ctx.param('id')
	id := id_str.int()

	// Find and remove user
	for i, user in app.users {
		if user.id == id {
			app.users.delete(i)
			return ctx.json({
				'message': 'user deleted'
			})
		}
	}

	ctx.res.status_code = http.Status.not_found
	return ctx.json({
		'error': 'user not found'
	})
}

// health handles GET /health
@['/health']
pub fn (mut app App) health(mut ctx veb.Context) veb.Result {
	return ctx.json({
		'status':    'healthy'
		'timestamp': veb.now()
	})
}

// CORS middleware
pub fn (mut app App) cors(mut ctx veb.Context) bool {
	origin := ctx.req.get_header('Origin')
	ctx.res.add_header('Access-Control-Allow-Origin', if origin == '' { '*' } else { origin })
	ctx.res.add_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
	ctx.res.add_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')

	if ctx.req.method == 'OPTIONS' {
		ctx.res.status_code = http.Status.ok
		return false
	}

	return true
}

fn main() {
	mut app := new_app()

	println('Server starting on http://localhost:8080')
	println('Routes:')
	println('  GET    /              - Welcome page')
	println('  GET    /api/users     - List users')
	println('  GET    /api/users/:id - Get user')
	println('  POST   /api/users     - Create user')
	println('  PUT    /api/users/:id - Update user')
	println('  DELETE /api/users/:id - Delete user')
	println('  GET    /health        - Health check')

	veb.run[App](mut app, 8080)
}
