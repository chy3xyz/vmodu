// sandbox.v - WASM Sandbox for secure AI Tool execution
//
// EXPERIMENTAL: This module does NOT run a real WASM engine today.
// `execute` only host-simulates a few string transforms unless
// VVMODU_WASM_SIMULATE=1 is set. Prefer `execute_simulated` when you
// intentionally want the stub behavior in tests/dev.

module sandbox

import os

const (
	default_memory_limit = 16 * 1024 * 1024 // 16MB
	default_cpu_time_ms  = 5000             // 5 seconds
	default_call_depth   = 100
)

// WasmModule represents a loaded WASM module
pub struct WasmModule {
pub:
	name    string
	hash    string // SHA256 of module bytes
mut:
	code    []u8
	exports []string
}

// ExecutionResult contains the result of WASM execution
pub struct ExecutionResult {
pub:
	success     bool
	output      string
	error_msg   string
	cpu_time    i64
	memory_used u64
}

// ResourceUsage tracks resource consumption
pub struct ResourceUsage {
pub mut:
	cpu_time_ms  i64
	memory_bytes u64
	call_depth   int
}

// WasmSandbox provides isolated execution environment
@[heap]
pub struct WasmSandbox {
pub mut:
	modules        map[string]WasmModule
	memory_limit   u64
	cpu_time_ms    u64
	max_call_depth int
	running        bool
}

// new_sandbox creates a new WASM Sandbox
pub fn new_sandbox() &WasmSandbox {
	return &WasmSandbox{
		modules:        {}
		memory_limit:   default_memory_limit
		cpu_time_ms:    default_cpu_time_ms
		max_call_depth: default_call_depth
		running:        false
	}
}

// with_limits configures resource limits
pub fn (mut ws WasmSandbox) with_limits(memory u64, cpu_ms u64) {
	ws.memory_limit = memory
	ws.cpu_time_ms = cpu_ms
}

// load_module loads a WASM module into the sandbox
pub fn (mut ws WasmSandbox) load_module(name string, code []u8) ! {
	if name in ws.modules {
		return error('module ${name} already loaded')
	}

	// Validate WASM header (magic number: \x00asm)
	if code.len < 4 || code[0] != 0x00 || code[1] != 0x61 || code[2] != 0x73 || code[3] != 0x6d {
		return error('invalid WASM module')
	}

	// Calculate hash for integrity
	hash := calculate_hash(code)

	// Parse exports from WASM (simplified)
	exports := parse_exports(code)

	mod := WasmModule{
		name:    name
		hash:    hash
		code:    code.clone()
		exports: exports
	}

	ws.modules[name] = mod
}

// unload_module removes a module from the sandbox
pub fn (mut ws WasmSandbox) unload_module(name string) {
	ws.modules.delete(name)
}

// wasm_simulate_enabled is true when host-side WASM simulation is allowed.
fn wasm_simulate_enabled() bool {
	return os.getenv('VVMODU_WASM_SIMULATE') == '1'
}

// execute runs a function in the WASM sandbox.
// Without VVMODU_WASM_SIMULATE=1 this returns an error — there is no real WASM VM yet.
pub fn (mut ws WasmSandbox) execute(module_name string, func_name string, input string) ExecutionResult {
	if !wasm_simulate_enabled() {
		return ExecutionResult{
			success:     false
			output:      ''
			error_msg:   'WASM execute is experimental simulation only; set VVMODU_WASM_SIMULATE=1 to allow, or call execute_simulated()'
			cpu_time:    0
			memory_used: 0
		}
	}
	return ws.execute_simulated(module_name, func_name, input)
}

// execute_simulated host-simulates a few string tools — NOT a real WASM engine.
// Explicit opt-in for tests/dev; production should wait for a real runtime.
pub fn (mut ws WasmSandbox) execute_simulated(module_name string, func_name string, input string) ExecutionResult {
	if module_name !in ws.modules {
		return ExecutionResult{
			success:     false
			output:      ''
			error_msg:   'module not found: ${module_name}'
			cpu_time:    0
			memory_used: 0
		}
	}

	mod := ws.modules[module_name]

	// Check if function exists
	if func_name !in mod.exports {
		return ExecutionResult{
			success:     false
			output:      ''
			error_msg:   'function not found: ${func_name}'
			cpu_time:    0
			memory_used: 0
		}
	}

	// Initialize resource tracking
	mut usage := ResourceUsage{
		cpu_time_ms:  0
		memory_bytes: 0
		call_depth:   0
	}

	start_time := get_timestamp_ms()

	result := simulate_execution(mod, func_name, input, mut usage)

	end_time := get_timestamp_ms()
	cpu_time := end_time - start_time

	// Check resource limits
	if u64(usage.memory_bytes) > ws.memory_limit {
		return ExecutionResult{
			success:     false
			output:      ''
			error_msg:   'memory limit exceeded: ${usage.memory_bytes} > ${ws.memory_limit}'
			cpu_time:    cpu_time
			memory_used: u64(usage.memory_bytes)
		}
	}

	if u64(cpu_time) > ws.cpu_time_ms {
		return ExecutionResult{
			success:     false
			output:      ''
			error_msg:   'cpu time limit exceeded: ${cpu_time} > ${ws.cpu_time_ms}'
			cpu_time:    cpu_time
			memory_used: u64(usage.memory_bytes)
		}
	}

	return ExecutionResult{
		success:     result.success
		output:      result.output
		error_msg:   result.error_msg
		cpu_time:    cpu_time
		memory_used: u64(usage.memory_bytes)
	}
}

// simulate_execution host-simulates WASM (replace with actual runtime)
fn simulate_execution(mod WasmModule, func_name string, input string, mut usage ResourceUsage) ExecutionResult {
	usage.memory_bytes = u64(input.len * 2)

	mut output := 'executed ${func_name} with input: ${input}'

	// Simulate tool behavior based on function name
	match func_name {
		'echo' {
			output = input
		}
		'uppercase' {
			output = input.to_upper()
		}
		'lowercase' {
			output = input.to_lower()
		}
		'reverse' {
			mut reversed := ''
			for i := input.len - 1; i >= 0; i-- {
				reversed += input[i].ascii_str()
			}
			output = reversed
		}
		else {
			output = 'unknown function: ${func_name}'
		}
	}

	return ExecutionResult{
		success:     true
		output:      output
		error_msg:   ''
		cpu_time:    1
		memory_used: usage.memory_bytes
	}
}

// parse_exports extracts exported functions from WASM (simplified)
fn parse_exports(code []u8) []string {
	return ['echo', 'uppercase', 'lowercase', 'reverse', 'add', 'multiply']
}

// get_module retrieves a loaded module
pub fn (ws &WasmSandbox) get_module(name string) ?WasmModule {
	return ws.modules[name] or { return none }
}

// list_modules returns all loaded module names
pub fn (ws &WasmSandbox) list_modules() []string {
	mut names := []string{cap: ws.modules.len}
	for name, _ in ws.modules {
		names << name
	}
	names.sort()
	return names
}

// get_stats returns sandbox statistics
pub fn (ws &WasmSandbox) get_stats() SandboxStats {
	mut total_memory := u64(0)
	for _, mod in ws.modules {
		total_memory += u64(mod.code.len)
	}

	return SandboxStats{
		module_count: ws.modules.len
		total_memory: total_memory
		memory_limit: ws.memory_limit
		cpu_limit_ms: ws.cpu_time_ms
	}
}

// SandboxStats contains sandbox metrics
pub struct SandboxStats {
pub:
	module_count int
	total_memory u64
	memory_limit u64
	cpu_limit_ms u64
}

// calculate_hash calculates SHA256 hash of data (placeholder)
fn calculate_hash(data []u8) string {
	mut hash := ''
	for i, b in data {
		if i < 8 {
			hash += b.hex()
		}
	}
	return hash
}

// get_timestamp_ms returns current timestamp in milliseconds
fn get_timestamp_ms() i64 {
	return 0 // Placeholder
}

// WasmTool adapts a WASM module as an Agent Tool
pub struct WasmTool {
pub:
	name_        string
	description_ string
	module_name  string
	func_name    string
mut:
	sandbox &WasmSandbox
}

// name returns the tool name
pub fn (t &WasmTool) name() string {
	return t.name_
}

// description returns the tool description
pub fn (t &WasmTool) description() string {
	return t.description_
}

// run executes the tool via host simulation (experimental; same guard as execute)
pub fn (mut t WasmTool) run(input string) string {
	result := t.sandbox.execute(t.module_name, t.func_name, input)
	if result.success {
		return result.output
	}
	return 'error: ${result.error_msg}'
}

// new_wasm_tool creates a new WASM-based tool
pub fn new_wasm_tool(sandbox &WasmSandbox, name string, description string, module_name string, func_name string) WasmTool {
	return WasmTool{
		name_:        name
		description_: description
		module_name:  module_name
		func_name:    func_name
		sandbox:      sandbox
	}
}
