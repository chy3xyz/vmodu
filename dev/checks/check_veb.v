module main

import vmodu.adapter.veb_adapter

fn main() {
	mut app := veb_adapter.new_app()
	_ = app
	println('veb adapter ok')
}
