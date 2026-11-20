// sandbox_test.v - Unit tests for WASM sandbox module
// Simulation paths use execute_simulated(); execute() requires VVMODU_WASM_SIMULATE=1.

module sandbox

import os

fn test_new_sandbox() {
	s := new_sandbox()

	assert s.modules.len == 0
	assert s.memory_limit == default_memory_limit
	assert s.cpu_time_ms == default_cpu_time_ms
	assert s.max_call_depth == default_call_depth
	assert s.running == false
}

fn test_with_limits() {
	mut s := new_sandbox()
	s.with_limits(32 * 1024 * 1024, 10000)

	assert s.memory_limit == 32 * 1024 * 1024
	assert s.cpu_time_ms == 10000
}

fn test_load_module() {
	mut s := new_sandbox()

	// Valid WASM magic number: \x00asm
	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

	s.load_module('test', wasm_code) or {
		assert false, 'load failed: ${err}'
	}

	assert s.modules.len == 1
	assert 'test' in s.modules

	// Should fail to load duplicate
	mut failed := false
	s.load_module('test', wasm_code) or {
		failed = true
	}
	assert failed == true
}

fn test_load_invalid_module() {
	mut s := new_sandbox()

	// Invalid WASM (wrong magic number)
	invalid_code := [u8(0x00), 0x00, 0x00, 0x00]

	mut failed := false
	s.load_module('invalid', invalid_code) or {
		failed = true
	}
	assert failed == true
}

fn test_unload_module() {
	mut s := new_sandbox()

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	assert s.modules.len == 1

	s.unload_module('test')

	assert s.modules.len == 0
}

fn test_get_module() {
	mut s := new_sandbox()

	// Should return none for non-existent module
	result := s.get_module('non-existent')
	assert result == none

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result2 := s.get_module('test')
	assert result2 != none
}

fn test_list_modules() {
	mut s := new_sandbox()

	names := s.list_modules()
	assert names.len == 0

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('module1', wasm_code)!
	s.load_module('module2', wasm_code)!

	names2 := s.list_modules()
	assert names2.len == 2
	assert 'module1' in names2
	assert 'module2' in names2
}

fn test_execute_requires_simulate_env() {
	mut s := new_sandbox()
	os.unsetenv('VVMODU_WASM_SIMULATE')

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result := s.execute('test', 'echo', 'hello')
	assert result.success == false
	assert result.error_msg.contains('VVMODU_WASM_SIMULATE')
}

fn test_execute_unknown_module() {
	mut s := new_sandbox()

	result := s.execute_simulated('unknown', 'echo', 'hello')

	assert result.success == false
	assert result.error_msg.contains('module not found')
}

fn test_execute_unknown_function() {
	mut s := new_sandbox()

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result := s.execute_simulated('test', 'unknown_function', 'hello')

	assert result.success == false
	assert result.error_msg.contains('function not found')
}

fn test_execute_echo() {
	mut s := new_sandbox()

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result := s.execute_simulated('test', 'echo', 'hello world')

	assert result.success == true
	assert result.output == 'hello world'
}

fn test_execute_uppercase() {
	mut s := new_sandbox()

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result := s.execute_simulated('test', 'uppercase', 'hello')

	assert result.success == true
	assert result.output == 'HELLO'
}

fn test_execute_lowercase() {
	mut s := new_sandbox()

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result := s.execute_simulated('test', 'lowercase', 'HELLO')

	assert result.success == true
	assert result.output == 'hello'
}

fn test_execute_reverse() {
	mut s := new_sandbox()

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	result := s.execute_simulated('test', 'reverse', 'hello')

	assert result.success == true
	assert result.output == 'olleh'
}

fn test_get_stats() {
	mut s := new_sandbox()

	stats := s.get_stats()
	assert stats.module_count == 0
	assert stats.total_memory == 0

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	stats2 := s.get_stats()
	assert stats2.module_count == 1
	assert stats2.total_memory == u64(wasm_code.len)
}

fn test_wasm_tool() {
	mut s := new_sandbox()
	os.setenv('VVMODU_WASM_SIMULATE', '1', true)

	wasm_code := [u8(0x00), 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]
	s.load_module('test', wasm_code)!

	mut tool := new_wasm_tool(s, 'echo_tool', 'Echoes input', 'test', 'echo')

	assert tool.name() == 'echo_tool'
	assert tool.description() == 'Echoes input'

	result := tool.run('hello')
	assert result == 'hello'
}
