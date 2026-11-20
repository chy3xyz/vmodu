// demo.v - Scaffold Module Usage Example
// Demonstrates programmatic usage of the scaffold module

module main

import vmodu.scaffold
import os

fn main() {
	println('╔════════════════════════════════════════════════════════════╗')
	println('║       VModu Runtime - Scaffold Module Demo                  ║')
	println('╚════════════════════════════════════════════════════════════╝')
	println('')

	// 1. List available templates
	println('📋 Available Templates:')
	println('')
	templates := scaffold.available_templates()
	for t in templates {
		println('  ${t.name:12} - ${t.description}')
	}
	println('')

	// 2. Generate a minimal project
	output_dir := os.temp_dir()
	project_name := 'demo_app'

	println('🔨 Generating project: ${project_name}')
	println('   Template: minimal')
	println('   Output: ${output_dir}/${project_name}')
	println('')

	scaffold.generate_project(project_name, 'minimal', output_dir) or {
		eprintln('❌ Failed to generate project: ${err}')
		return
	}

	println('✅ Project generated successfully!')
	println('')

	// 3. Show generated structure
	project_path := os.join_path(output_dir, project_name)
	println('📁 Generated Structure:')
	println('')
	show_structure(project_path, 0)
	println('')

	// 4. Generate a module
	println('🔨 Generating module: user')
	scaffold.generate_module(project_path, 'user', scaffold.ModuleTemplate{
		name: 'user'
		has_events: true
		has_handlers: true
		has_tests: true
	}) or {
		eprintln('❌ Failed to generate module: ${err}')
		return
	}
	println('✅ Module generated!')
	println('')

	// 5. Generate an Actor
	println('🔨 Generating actor: worker')
	scaffold.generate_actor(project_path, 'worker') or {
		eprintln('❌ Failed to generate actor: ${err}')
		return
	}
	println('✅ Actor generated!')
	println('')

	// 6. Generate an HTTP handler
	println('🔨 Generating HTTP handler: users')
	scaffold.generate_http_handler(project_path, 'users') or {
		eprintln('❌ Failed to generate handler: ${err}')
		return
	}
	println('✅ Handler generated!')
	println('')

	// Final structure
	println('📁 Final Project Structure:')
	println('')
	show_structure(project_path, 0)
	println('')

	// Show sample code
	println('📝 Sample Generated Code:')
	println('')
	show_sample_code(project_path)

	// Cleanup
	println('')
	println('🧹 Cleaning up temporary files...')
	os.rmdir_all(project_path) or {}
	println('✅ Cleanup complete!')

	println('')
	println('╔════════════════════════════════════════════════════════════╗')
	println('║  Demo completed! Use vmodu-cli for command-line access.    ║')
	println('╚════════════════════════════════════════════════════════════╝')
}

fn show_structure(path string, indent int) {
	prefix := '  '.repeat(indent)
	entries := os.ls(path) or { return }

	for entry in entries {
		full_path := os.join_path(path, entry)
		if os.is_dir(full_path) {
			println('${prefix}📂 ${entry}/')
			show_structure(full_path, indent + 1)
		} else {
			println('${prefix}📄 ${entry}')
		}
	}
}

fn show_sample_code(project_path string) {
	// Show main.v sample
	main_file := os.join_path(project_path, 'main.v')
	if content := os.read_file(main_file) {
		lines := content.split('\n')
		println('--- main.v ---')
		for i, line in lines {
			if i >= 20 {
				println('...')
				break
			}
			println(line)
		}
	}

	// Show module sample
	module_file := os.join_path(project_path, 'src/modules/user/user.v')
	if content := os.read_file(module_file) {
		println('')
		println('--- src/modules/user/user.v ---')
		lines := content.split('\n')
		for i, line in lines {
			if i >= 15 {
				println('...')
				break
			}
			println(line)
		}
	}
}
