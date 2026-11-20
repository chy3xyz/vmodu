// 05-veb-simple.v - Simple veb example
// Note: veb API is evolving in V 0.5.0, this is a conceptual example

module main

import veb
import time

pub struct App {
veb.Controller
}

pub fn (mut app App) index(mut ctx veb.Context) veb.Result {
	return ctx.html('<h1>Hello from veb!</h1>')
}

pub fn (mut app App) hello(mut ctx veb.Context) veb.Result {
	name := ctx.query('name', 'World')
	return ctx.json({
		'message': 'Hello, ${name}!'
		'time': time.now().format_ss()
	})
}

fn main() {
	mut app := App{}
	println('veb server on http://localhost:8080')
	// Note: veb.run syntax may vary by V version
}
