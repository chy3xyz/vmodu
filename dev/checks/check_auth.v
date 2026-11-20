module main

import vmodu.infra.auth

fn main() {
	mgr := auth.new_jwt_manager(auth.JWTConfig{
		secret: 'test-secret-key-32bytes!!!!'
	})
	token := mgr.generate('u1', ['admin'], ['read']) or { panic(err) }
	payload := mgr.verify(token) or { panic(err) }
	println('auth ok user=${payload.sub}')
}
