// modulith.v - Modular Monolith Core Framework

module core

import vmodu.event.bus

// Module is the interface that all business modules must implement
pub interface Module {
mut:
	init(event_bus &bus.EventBus) !
	start() !
	stop() !
}

// ModuleInfo holds module metadata
pub struct ModuleInfo {
pub:
	name        string
	version     string
	description string
	author      string
}

// Container manages all registered modules
@[heap]
pub struct Container {
pub mut:
	modules     map[string]Module
	infos       map[string]ModuleInfo
	event_bus   &bus.EventBus
	running     bool
}

// BaseModule provides common functionality for modules
pub struct BaseModule {
pub:
	mod_name    string
	mod_version string
}

// new_container creates a new Container
pub fn new_container() &Container {
	return &Container{
		modules:   {}
		infos:     {}
		event_bus: bus.default()
	}
}

// with_event_bus creates container with custom event bus
pub fn (mut c Container) with_event_bus(event_bus &bus.EventBus) &Container {
	c.event_bus = event_bus
	return c
}

// register adds a module to the container
pub fn (mut c Container) register(name string, m Module) ! {
	if name in c.modules {
		return error('module already registered: ${name}')
	}
	c.modules[name] = m
}

// register_with_info adds module with metadata
pub fn (mut c Container) register_with_info(name string, m Module, info ModuleInfo) ! {
	c.register(name, m)!
	c.infos[name] = info
}

// unregister removes a module from the container
pub fn (mut c Container) unregister(name string) ! {
	if name !in c.modules {
		return error('module not found: ${name}')
	}
	c.modules.delete(name)
	c.infos.delete(name)
}

// get retrieves a module by name
pub fn (mut c Container) get(name string) ?Module {
	return c.modules[name] or { return none }
}

// get_info retrieves module info
pub fn (mut c Container) get_info(name string) ?ModuleInfo {
	return c.infos[name] or { return none }
}

// list returns all registered module names
pub fn (mut c Container) list() []string {
	mut names := []string{cap: c.modules.len}
	for name, _ in c.modules {
		names << name
	}
	names.sort()
	return names
}

// init initializes all registered modules
pub fn (mut c Container) init() ! {
	for _, mut m in c.modules {
		m.init(c.event_bus) or {
			return error('failed to initialize module: ${err}')
		}
	}
}

// start starts all registered modules
pub fn (mut c Container) start() ! {
	if c.running {
		return error('container already running')
	}
	
	c.init() or { return err }
	
	for _, mut m in c.modules {
		m.start() or {
			return error('failed to start module: ${err}')
		}
	}
	
	c.running = true
}

// stop stops all registered modules
pub fn (mut c Container) stop() ! {
	if !c.running {
		return
	}
	
	for _, mut m in c.modules {
		m.stop() or { }
	}
	
	c.running = false
}

// is_running returns container status
pub fn (c &Container) is_running() bool {
	return c.running
}

// get_event_bus returns the container's event bus
pub fn (c &Container) get_event_bus() &bus.EventBus {
	return c.event_bus
}

// new_base_module creates a new BaseModule
pub fn new_base_module(name string, version string) BaseModule {
	return BaseModule{
		mod_name:    name
		mod_version: version
	}
}

// base_name returns the module name
pub fn (b &BaseModule) base_name() string {
	return b.mod_name
}

// base_version returns the module version
pub fn (b &BaseModule) base_version() string {
	return b.mod_version
}
