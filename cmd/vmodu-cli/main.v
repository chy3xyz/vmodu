// vmodu-cli - VModu Runtime Command Line Tool
// Provides scaffolding and project management utilities

module main

import os
import vmodu.scaffold

const (
	version = '0.1.0'
)

fn main() {
	if os.args.len < 2 {
		print_usage()
		return
	}

	cmd := os.args[1]

	match cmd {
		'new', 'n' { cmd_new() }
		'generate', 'g' { cmd_generate() }
		'list', 'l' { cmd_list() }
		'help', '-h', '--help' { print_usage() }
		'version', '-v', '--version' { println('vmodu-cli v${version}') }
		else {
			eprintln('Unknown command: ${cmd}')
			print_usage()
			exit(1)
		}
	}
}

fn print_usage() {
	println('VModu Runtime CLI v${version}')
	println('')
	println('Usage:')
	println('  vmodu-cli <command> [options]')
	println('')
	println('Commands:')
	println('  new, n <name> [template]  Create a new project')
	println('  generate, g <type> <name> Generate module/component')
	println('  list, l                   List available templates')
	println('  help                      Show this help message')
	println('  version                   Show version')
	println('')
	println('Examples:')
	println('  vmodu-cli new myapp web-api')
	println('  vmodu-cli generate module user --events --handlers')
	println('  vmodu-cli generate actor worker')
	println('  vmodu-cli generate handler users')
	println('')
	println('Templates:')
	templates := scaffold.available_templates()
	for t in templates {
		println('  ${t.name:12} - ${t.description}')
	}
}

fn cmd_new() {
	if os.args.len < 3 {
		eprintln('Usage: vmodu-cli new <name> [template]')
		eprintln('Run "vmodu-cli list" to see available templates')
		exit(1)
	}

	name := os.args[2]
	mut template := 'minimal'

	if os.args.len > 3 {
		template = os.args[3]
	}

	output_dir := os.getwd()

	println('Creating new project: ${name}')
	println('Template: ${template}')
	println('Output: ${output_dir}')
	println('')

	scaffold.generate_project(name, template, output_dir) or {
		eprintln('Error: ${err}')
		exit(1)
	}
}

fn cmd_generate() {
	if os.args.len < 4 {
		eprintln('Usage: vmodu-cli generate <type> <name> [options]')
		eprintln('')
		eprintln('Types:')
		eprintln('  module <name>  Generate business module')
		eprintln('  actor <name>   Generate Actor module')
		eprintln('  handler <name> Generate HTTP handler')
		eprintln('')
		eprintln('Options for module:')
		eprintln('  --events       Include event handling')
		eprintln('  --handlers     Include event handlers')
		eprintln('  --no-tests     Skip test file generation')
		exit(1)
	}

	gen_type := os.args[2]
	name := os.args[3]
	project_dir := os.getwd()

	match gen_type {
		'module', 'm' {
			opts := parse_module_options()
			scaffold.generate_module(project_dir, name, opts) or {
				eprintln('Error: ${err}')
				exit(1)
			}
		}
		'actor', 'a' {
			scaffold.generate_actor(project_dir, name) or {
				eprintln('Error: ${err}')
				exit(1)
			}
		}
		'handler', 'h' {
			scaffold.generate_http_handler(project_dir, name) or {
				eprintln('Error: ${err}')
				exit(1)
			}
		}
		else {
			eprintln('Unknown generator type: ${gen_type}')
			exit(1)
		}
	}
}

fn parse_module_options() scaffold.ModuleTemplate {
	return scaffold.ModuleTemplate{
		name:         ''
		has_events:   has_flag('--events')
		has_handlers: has_flag('--handlers')
		has_tests:    !has_flag('--no-tests')
	}
}

fn has_flag(flag string) bool {
	for arg in os.args {
		if arg == flag {
			return true
		}
	}
	return false
}

fn cmd_list() {
	println('Available Templates:')
	println('')

	templates := scaffold.available_templates()
	for t in templates {
		println('  ${t.name}')
		println('    ${t.description}')
		println('    Modules: ${t.modules}')
		println('')
	}
}
