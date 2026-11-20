// modulith_test.v - Unit tests for modulith module

module core

import vmodu.event.bus

// TestModule implements the Module interface for testing
struct TestModule {
pub:
	base BaseModule
mut:
	initialized bool
	started     bool
	stopped     bool
}

fn new_test_module(name string, version string) TestModule {
	return TestModule{
		base:        new_base_module(name, version)
		initialized: false
		started:     false
		stopped:     false
	}
}

fn (mut m TestModule) init(event_bus &bus.EventBus) ! {
	m.initialized = true
}

fn (mut m TestModule) start() ! {
	m.started = true
}

fn (mut m TestModule) stop() ! {
	m.stopped = true
}

fn test_new_container() {
	mut c := new_container()
	assert c != unsafe { nil }
	assert c.running == false
	assert c.modules.len == 0
}

fn test_register_module() {
	mut c := new_container()
	mut m := new_test_module('test-module', '1.0.0')
	
	c.register('test-module', m)!
	
	assert c.modules.len == 1
	assert 'test-module' in c.list()
}

fn test_register_duplicate() {
	mut c := new_container()
	mut m1 := new_test_module('test-module', '1.0.0')
	mut m2 := new_test_module('test-module', '2.0.0')
	
	c.register('test-module', m1)!
	
	// Test error case - should fail with duplicate error
	mut failed := false
	c.register('test-module', m2) or {
		assert err.msg().contains('already registered')
		failed = true
	}
	assert failed, 'should have failed'
}

fn test_unregister_module() {
	mut c := new_container()
	mut m := new_test_module('test-module', '1.0.0')
	
	c.register('test-module', m)!
	assert c.modules.len == 1
	
	c.unregister('test-module')!
	assert c.modules.len == 0
}

fn test_get_module() {
	mut c := new_container()
	mut m := new_test_module('test-module', '1.0.0')
	
	c.register('test-module', m)!
	
	result := c.get('test-module')
	assert result != none
	
	not_found := c.get('non-existent')
	assert not_found == none
}

fn test_list_modules() {
	mut c := new_container()
	mut m1 := new_test_module('module-a', '1.0.0')
	mut m2 := new_test_module('module-b', '1.0.0')
	
	c.register('module-a', m1)!
	c.register('module-b', m2)!
	
	names := c.list()
	assert names.len == 2
	assert 'module-a' in names
	assert 'module-b' in names
}

fn test_lifecycle() {
	mut c := new_container()
	mut m := new_test_module('test-module', '1.0.0')
	
	c.register('test-module', m)!
	c.start()!
	
	assert c.is_running() == true
	
	c.stop()!
	assert c.is_running() == false
}

fn test_register_with_info() {
	mut c := new_container()
	mut m := new_test_module('test-module', '1.0.0')
	info := ModuleInfo{
		name:        'test-module'
		version:     '1.0.0'
		description: 'A test module'
		author:      'tester'
	}
	
	c.register_with_info('test-module', m, info)!
	
	result := c.get_info('test-module')
	assert result != none
}
