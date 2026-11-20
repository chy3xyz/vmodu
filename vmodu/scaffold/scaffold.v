// scaffold.v - VModulith Runtime Application Scaffolding
// Provides standardized project templates and generation utilities
// v3.3: Updated to follow VModulith best practices

module scaffold

import os

// ProjectTemplate represents a project scaffolding template
pub struct ProjectTemplate {
pub:
	name        string
	description string
	modules     []string // Required vmodu
}

// ModuleTemplate represents a module scaffolding template
pub struct ModuleTemplate {
pub:
	name         string
	has_events   bool
	has_handlers bool
	has_tests    bool
}

// available_templates returns all available project templates
pub fn available_templates() []ProjectTemplate {
	return [
		ProjectTemplate{
			name:        'minimal'
			description: 'Minimal project with core and event bus'
			modules:     ['core', 'event/bus']
		},
		ProjectTemplate{
			name:        'web-api'
			description: 'Web API with HTTP server and health checks'
			modules:     ['core', 'event/bus', 'infra/http', 'infra/health', 'infra/metrics']
		},
		ProjectTemplate{
			name:        'agent-ai'
			description: 'AI Agent with planner and tools'
			modules:     ['core', 'event/bus', 'agent/planner', 'agent/tool', 'agent/llm']
		},
		ProjectTemplate{
			name:        'blockchain'
			description: 'Blockchain application with EVM/Solana support'
			modules:     ['core', 'event/bus', 'adapters/evm', 'adapters/solana', 'infra/health']
		},
		ProjectTemplate{
			name:        'distributed'
			description: 'Distributed cluster application'
			modules:     ['core', 'event/bus', 'cluster/node', 'cluster/shard', 'runtime/actor']
		},
		ProjectTemplate{
			name:        'ecommerce'
			description: 'E-commerce application with full infrastructure'
			modules:     [
				'core',
				'event/bus',
				'infra/http',
				'infra/db/sql',
				'infra/cache/redis',
				'infra/auth/jwt',
				'infra/storage/oss',
				'infra/payment',
				'infra/search',
				'infra/mq',
				'infra/scheduler',
				'infra/validator',
				'infra/template',
			]
		},
		ProjectTemplate{
			name:        'fullstack'
			description: 'Full stack with all features'
			modules:     [
				'core',
				'event/bus',
				'runtime/actor',
				'cluster/node',
				'cluster/shard',
				'agent/planner',
				'agent/tool',
				'adapters/evm',
				'adapters/solana',
				'infra/health',
				'infra/metrics',
				'infra/circuit',
				'infra/http',
				'infra/ws',
				'infra/db/sql',
				'infra/cache/redis',
				'wasm/sandbox',
			]
		},
	]
}

// generate_project generates a new project from template
pub fn generate_project(name string, template_name string, output_dir string) ! {
	// Validate template
	templates := available_templates()
	mut found := false
	mut template := ProjectTemplate{}
	for t in templates {
		if t.name == template_name {
			found = true
			template = t
			break
		}
	}
	if !found {
		return error('Unknown template: ${template_name}')
	}

	project_dir := os.join_path(output_dir, name)

	// Create directory structure
	create_directory_structure(project_dir)!

	// Generate files
	generate_vmod(name, project_dir)!
	generate_main(name, template, project_dir)!
	generate_config(project_dir)!
	generate_app_module(name, template, project_dir)!
	generate_readme(name, template, project_dir)!

	println('Generated project ${name} at ${project_dir}')
	println('Template: ${template.description}')
	println('Modules: ${template.modules}')
	println('\nNext steps:')
	println('  cd ${project_dir}')
	println('  v -enable-globals run main.v')
}

// generate_module generates a new business module
pub fn generate_module(project_dir string, module_name string, opts ModuleTemplate) ! {
	module_dir := os.join_path(project_dir, 'src/modules', module_name)
	os.mkdir_all(module_dir)!

	// Generate module file
	generate_module_file(module_dir, module_name, opts)!

	// Generate handler file if needed
	if opts.has_handlers {
		generate_handler_file(module_dir, module_name)!
	}

	// Generate test file if needed
	if opts.has_tests {
		generate_test_file(module_dir, module_name, opts)!
	}

	println('Generated module ${module_name} at ${module_dir}')
}

// create_directory_structure creates the project directory structure
fn create_directory_structure(project_dir string) ! {
	dirs := [
		'src/modules',
		'src/services',
		'src/models',
		'config',
		'tests',
		'docs',
	]

	for dir in dirs {
		full_path := os.join_path(project_dir, dir)
		os.mkdir_all(full_path)!
	}
}

// generate_vmod generates v.mod file
fn generate_vmod(name string, project_dir string) ! {
	content := "Module {
	name: '${name}'
	description: 'VModulith Runtime Application'
	version: '0.1.0'
	license: 'MIT'
	dependencies: []
}
"
	os.write_file(os.join_path(project_dir, 'v.mod'), content)!
}

// generate_main generates main.v file
fn generate_main(name string, template ProjectTemplate, project_dir string) ! {
	mut imports := ''
	mut init_code := ''

	// Add imports based on template
	if 'core' in template.modules {
		imports += 'import vmodu.core { new_container }\n'
		init_code += '
	// Create container
	mut container := new_container()'
	}

	if 'event/bus' in template.modules {
		imports += 'import vmodu.event.bus\n'
	}

	if 'infra/health' in template.modules {
		imports += 'import vmodu.infra.health { new_checker }\n'
		init_code += '
	// Setup health checks
	mut health_checker := new_checker()
	container.register("health", health_checker)!'
	}

	if 'infra/http' in template.modules {
		imports += 'import vmodu.infra.http { new_server, ServerConfig }\n'
		init_code += '
	// Setup HTTP server
	server := new_server(ServerConfig{ port: 8080 })
	container.register("http", server)!'
	}

	if 'runtime/actor' in template.modules {
		imports += 'import vmodu.runtime.actor\n'
	}

	if 'infra/db/sql' in template.modules {
		imports += 'import vmodu.infra.db.sql { new_orm }\n'
		init_code += '
	// Setup database
	mut db := new_orm(.sqlite, "app.db")!
	container.register("db", db)!'
	}

	if 'infra/cache/redis' in template.modules {
		imports += 'import vmodu.infra.cache { new_redis_client }\n'
	}

	content := '// main.v - ${name} Application Entry Point
module main

${imports}
import os

fn main() {
	println("Starting ${name}...")
${init_code}
	
	// Initialize application module
	mut app := new_app_module()
	container.register("app", app)!
	
	// Start all modules
	container.start() or {
		eprintln("Failed to start: \${err}")
		exit(1)
	}
	
	println("${name} is running. Press Ctrl+C to stop.")
	
	// Keep running
	select {}
	
	// Graceful shutdown
	container.stop()!
}
'
	os.write_file(os.join_path(project_dir, 'main.v'), content)!
}

// generate_config generates config files
fn generate_config(project_dir string) ! {
	// JSON config
	json_config := '{
	"app": {
		"name": "VModulith App",
		"version": "0.1.0",
		"env": "development"
	},
	"server": {
		"host": "0.0.0.0",
		"port": 8080
	},
	"log": {
		"level": "info",
		"format": "json"
	}
}'
	os.write_file(os.join_path(project_dir, 'config/config.json'), json_config)!

	// Environment file
	env_content := '# Application Configuration
APP_NAME=VModulithApp
APP_ENV=development
APP_PORT=8080
LOG_LEVEL=info

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp
DB_USER=postgres
DB_PASSWORD=secret

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
'
	os.write_file(os.join_path(project_dir, 'config/.env.example'), env_content)!
}

// generate_app_module generates the main app module
fn generate_app_module(name string, template ProjectTemplate, project_dir string) ! {
	mut imports := 'import vmodu.core { Module }\nimport vmodu.event.bus'

	// Add template-specific imports
	if 'infra/http' in template.modules {
		imports += '\nimport vmodu.infra.http'
	}
	if 'infra/db/sql' in template.modules {
		imports += '\nimport vmodu.infra.db.sql'
	}

	content := '// app.v - Main Application Module
module main

${imports}

// AppModule is the main application module
pub struct AppModule {
pub mut:
	event_bus &bus.EventBus
	running   bool
}

// new_app_module creates a new application module
pub fn new_app_module() AppModule {
	return AppModule{
		event_bus: bus.default()
	}
}

// init initializes the module
pub fn (mut m AppModule) init(event_bus &bus.EventBus) ! {
	m.event_bus = event_bus
	
	// Subscribe to events
	m.event_bus.subscribe("app.start", on_app_start)
	
	println("App module initialized")
}

// start starts the module
pub fn (mut m AppModule) start() ! {
	m.running = true
	
	// Publish start event
	m.event_bus.publish(bus.Event{
		topic: "app.start"
		data:  "Application starting"
	})
	
	println("App module started")
}

// stop stops the module
pub fn (mut m AppModule) stop() ! {
	m.running = false
	println("App module stopped")
}

// Event handlers
fn on_app_start(event bus.Event) {
	println("Received app start event: \${event.data}")
}
'
	os.write_file(os.join_path(project_dir, 'src/app.v'), content)!
}

// generate_readme generates README.md
fn generate_readme(name string, template ProjectTemplate, project_dir string) ! {
	content := '# ${name}

${template.description}

## Quick Start

```bash
# Run the application
v -enable-globals run main.v

# Run tests
v -enable-globals test .

# Production build
v -enable-globals -prod -o ${name} .
```

## Project Structure

```
.
├── main.v              # Application entry point
├── v.mod               # V module definition
├── src/
│   ├── app.v          # Main application module
│   ├── modules/       # Business modules
│   ├── services/      # Service layer
│   └── models/        # Data models
├── config/            # Configuration files
├── tests/             # Integration tests
└── docs/              # Documentation
```

## Configuration

Copy `config/.env.example` to `config/.env` and configure:

```bash
cp config/.env.example config/.env
```

## Modules Used

${template.modules}

## Best Practices

This project follows [VModulith Runtime Best Practices](https://github.com/vmodu/runtime/blob/main/docs/BEST_PRACTICES.md):

- ✅ Use `?Type` instead of `unsafe { nil }`
- ✅ Use `!Type` for error handling
- ✅ Explicit `mut` for mutable state
- ✅ Standard library over external dependencies
- ✅ Proper error propagation with `or` blocks

## License

MIT
'
	os.write_file(os.join_path(project_dir, 'README.md'), content)!
}

// generate_module_file generates a business module
fn generate_module_file(module_dir string, module_name string, opts ModuleTemplate) ! {
	struct_name := module_name.capitalize() + 'Module'

	mut imports := 'import vmodu.core { Module }\n'
	mut fields := ''
	mut init_body := ''

	if opts.has_events {
		imports += 'import vmodu.event.bus\n'
		fields += '\t\tevent_bus &bus.EventBus\n'
		init_body += '\tm.event_bus = event_bus\n'
	}

	mut content := '// ${module_name}.v - ${struct_name}
module ${module_name}

${imports}

// ${struct_name} manages ${module_name} functionality
pub struct ${struct_name} {
pub mut:
${fields}
}

// new_${module_name}_module creates a new ${module_name} module
pub fn new_${module_name}_module() ${struct_name} {
	return ${struct_name}{}
}

// init initializes the module
pub fn (mut m ${struct_name}) init(event_bus &bus.EventBus) ! {
${init_body}	// TODO: Initialize ${module_name} module
	println("${module_name} module initialized")
}

// start starts the module
pub fn (mut m ${struct_name}) start() ! {
	println("${module_name} module started")
}

// stop stops the module
pub fn (mut m ${struct_name}) stop() ! {
	println("${module_name} module stopped")
}

// process handles data processing
pub fn (mut m ${struct_name}) process(data string) !string {
	// TODO: Implement processing logic
	return "processed: \${data}"
}
'
	os.write_file(os.join_path(module_dir, '${module_name}.v'), content)!
}

// generate_handler_file generates event handler file
fn generate_handler_file(module_dir string, module_name string) ! {
	struct_name := module_name.capitalize() + 'Module'

	content := '// handler.v - ${module_name.capitalize()} Event Handlers
module ${module_name}

import vmodu.event.bus

// subscribe_events subscribes to relevant events
pub fn (mut m ${struct_name}) subscribe_events() {
	m.event_bus.subscribe("${module_name}.created", on_created)
	m.event_bus.subscribe("${module_name}.updated", on_updated)
}

// Event handlers
fn on_created(event bus.Event) {
	println("${module_name} created: \${event.data}")
}

fn on_updated(event bus.Event) {
	println("${module_name} updated: \${event.data}")
}
'
	os.write_file(os.join_path(module_dir, 'handler.v'), content)!
}

// generate_test_file generates test file
fn generate_test_file(module_dir string, module_name string, opts ModuleTemplate) ! {
	mut imports := ''
	mut init_code := ''

	if opts.has_events {
		imports = 'import vmodu.event.bus { default }\n'
		init_code = '\tmut bus := default()
	module.init(bus)!
'
	}

	content := '// ${module_name}_test.v - Unit tests for ${module_name} module
module ${module_name}

${imports}
// test_new_${module_name}_module tests module creation
fn test_new_${module_name}_module() {
	m := new_${module_name}_module()
	assert m != unsafe { nil }
}

// test_${module_name}_lifecycle tests module lifecycle
fn test_${module_name}_lifecycle() ! {
	mut module := new_${module_name}_module()
${init_code}	module.start()!
	module.stop()!
}

// test_process tests data processing
fn test_process() ! {
	mut module := new_${module_name}_module()
	
	result := module.process("test data")!
	
	assert result.contains("processed")
	assert result.contains("test data")
}
'
	os.write_file(os.join_path(module_dir, '${module_name}_test.v'), content)!
}

// generate_actor generates an Actor module
pub fn generate_actor(project_dir string, actor_name string) ! {
	actor_dir := os.join_path(project_dir, 'src/modules', actor_name)
	os.mkdir_all(actor_dir)!

	struct_name := actor_name.capitalize() + 'Actor'

	content := '// ${actor_name}.v - ${struct_name}
module ${actor_name}

import vmodu.runtime.actor { Message, HandlerFunc }
import time

// ${struct_name} is an actor for ${actor_name}
pub struct ${struct_name} {
pub:
	id string
pub mut:
	mailbox       chan Message
	handler       ?HandlerFunc
	running       bool
	msg_processed u64
}

// Message types for ${actor_name}
pub struct ${struct_name}Message {
	pub:
	typ  string
	data string
}

// new_${actor_name} creates a new actor
pub fn new_${actor_name}(id string) &${struct_name} {
	return &${struct_name}{
		id:        id
		mailbox:   chan Message{cap: 100}
		handler:   none
		running:   false
	}
}

// set_handler sets the message handler
pub fn (mut a ${struct_name}) set_handler(handler HandlerFunc) {
	a.handler = handler
}

// start starts the actor
pub fn (mut a ${struct_name}) start() ! {
	if a.running {
		return error("actor already running")
	}
	a.running = true
	spawn a.run()
}

// stop stops the actor
pub fn (mut a ${struct_name}) stop() ! {
	a.running = false
}

// run is the main actor loop
fn (mut a ${struct_name}) run() {
	for a.running {
		select {
			msg := <-a.mailbox {
				a.handle(msg)
			}
		}
	}
}

// handle processes a message
fn (mut a ${struct_name}) handle(msg Message) {
	a.msg_processed++
	if handler := a.handler {
		// Call handler
		_ = handler
	}
}

// send sends a message to the actor
pub fn (mut a ${struct_name}) send(msg Message) ! {
	if !a.running {
		return error("actor not running")
	}
	select {
		a.mailbox <- msg { return }
		else { return error("mailbox full") }
	}
}

// send_with_timeout sends with timeout
pub fn (mut a ${struct_name}) send_with_timeout(msg Message, timeout time.Duration) ! {
	select {
		a.mailbox <- msg { return }
		timeout { return error("timeout") }
	}
}
'
	os.write_file(os.join_path(actor_dir, '${actor_name}.v'), content)!

	// Generate test file
	test_content := '// ${actor_name}_test.v - Tests for ${actor_name}
module ${actor_name}

import vmodu.runtime.actor { Message }
import time

fn test_new_${actor_name}() {
	actor := new_${actor_name}("test-1")
	assert actor.id == "test-1"
	assert actor.running == false
}

fn test_actor_lifecycle() ! {
	mut actor := new_${actor_name}("test-2")
	actor.start()!
	assert actor.running == true
	
	actor.stop()!
}

fn test_send_message() ! {
	mut actor := new_${actor_name}("test-3")
	actor.start()!
	
	msg := Message{
		sender: "test"
		data:   "hello"
	}
	
	actor.send(msg)!
	
	time.sleep(100 * time.millisecond)
	assert actor.msg_processed == 1
	
	actor.stop()!
}
'
	os.write_file(os.join_path(actor_dir, '${actor_name}_test.v'), test_content)!

	println('Generated actor ${actor_name} at ${actor_dir}')
}

// generate_http_handler generates HTTP handler module
pub fn generate_http_handler(project_dir string, handler_name string) ! {
	handler_dir := os.join_path(project_dir, 'src/modules', handler_name)
	os.mkdir_all(handler_dir)!

	struct_name := handler_name.capitalize() + 'Handler'

	content := '// ${handler_name}.v - HTTP Handler
module ${handler_name}

import vmodu.infra.http { Context, Response }
import json2

// ${struct_name} handles HTTP requests
pub struct ${struct_name} {}

// new_${handler_name} creates a new handler
pub fn new_${handler_name}() ${struct_name} {
	return ${struct_name}{}
}

// routes returns all routes for this handler
pub fn (h ${struct_name}) routes() []RouteDef {
	return [
		RouteDef{ method: "GET",  path: "/${handler_name}",      handler: h.list },
		RouteDef{ method: "GET",  path: "/${handler_name}/:id",  handler: h.get },
		RouteDef{ method: "POST", path: "/${handler_name}",      handler: h.create },
		RouteDef{ method: "PUT",  path: "/${handler_name}/:id",  handler: h.update },
		RouteDef{ method: "DELETE", path: "/${handler_name}/:id", handler: h.delete },
	]
}

// list returns all items
pub fn (h ${struct_name}) list(ctx Context) !Response {
	return Response{
		status_code: 200
		body:        json2.encode({"items": []}, escape_unicode: true, time_as_unix: true)
	}
}

// get returns a single item
pub fn (h ${struct_name}) get(ctx Context) !Response {
	id := ctx.params["id"] or { return error("missing id") }
	return Response{
		status_code: 200
		body:        json2.encode({"id": id}, escape_unicode: true, time_as_unix: true)
	}
}

// create creates a new item
pub fn (h ${struct_name}) create(ctx Context) !Response {
	return Response{
		status_code: 201
		body:        json2.encode({"created": true}, escape_unicode: true, time_as_unix: true)
	}
}

// update updates an item
pub fn (h ${struct_name}) update(ctx Context) !Response {
	id := ctx.params["id"] or { return error("missing id") }
	return Response{
		status_code: 200
		body:        json2.encode({"id": id, "updated": true}, escape_unicode: true, time_as_unix: true)
	}
}

// delete deletes an item
pub fn (h ${struct_name}) delete(ctx Context) !Response {
	id := ctx.params["id"] or { return error("missing id") }
	return Response{
		status_code: 204
		body:        ""
	}
}

// RouteDef defines a route
pub struct RouteDef {
pub:
	method  string
	path    string
	handler fn (Context) !Response
}
'
	os.write_file(os.join_path(handler_dir, '${handler_name}.v'), content)!

	// Generate test file
	test_content := '// ${handler_name}_test.v - Tests for ${handler_name}
module ${handler_name}

import vmodu.infra.http { Context, Response }
import json2

fn test_new_${handler_name}() {
	handler := new_${handler_name}()
	routes := handler.routes()
	assert routes.len == 5
}

fn test_list() ! {
	handler := new_${handler_name}()
	ctx := Context{}
	
	resp := handler.list(ctx)!
	assert resp.status_code == 200
}

fn test_get() ! {
	handler := new_${handler_name}()
	ctx := Context{
		params: {"id": "123"}
	}
	
	resp := handler.get(ctx)!
	assert resp.status_code == 200
}
'
	os.write_file(os.join_path(handler_dir, '${handler_name}_test.v'), test_content)!

	println('Generated HTTP handler ${handler_name} at ${handler_dir}')
}
