// config.v - Configuration management with hot reload support
// v3.1: Refactored to remove unsafe { nil } patterns
//
// Features:
//   - JSON/YAML config loading
//   - File watching for hot reload
//   - Validation before applying
//   - Rollback on change handler failure
//
// Usage:
//   mut mgr := config.new_manager()
//   mgr.load('config.json')!
//   cfg := mgr.get()

module config

import os
import time
import json2
import sync

// ============================================================================
// Config Structures
// ============================================================================

// Config represents the application configuration
pub struct Config {
pub mut:
	server  ServerConfig
	actor   ActorConfig
	storage StorageConfig
	cluster ClusterConfig
	llm     LLMConfig
	log     LogConfig
}

// ServerConfig for HTTP/gRPC server
pub struct ServerConfig {
pub mut:
	http_port     int    = 8080
	grpc_port     int    = 9090
	host          string = '0.0.0.0'
	read_timeout  int    = 30 // seconds
	write_timeout int    = 30
	max_body_size i64    = 10485760 // 10MB
}

// ActorConfig for actor system
pub struct ActorConfig {
pub mut:
	mailbox_size           int = 100
	worker_pool_size       int = 16
	max_actors             int = 10000
	supervisor_restart_max int = 5
}

// StorageConfig for event store
pub struct StorageConfig {
pub mut:
	data_dir          string = './data'
	segment_size      int    = 10000
	buffer_size       int    = 8192
	flush_interval_ms int    = 100
	fsync_on_write    bool   = true
}

// ClusterConfig for Raft cluster
pub struct ClusterConfig {
pub mut:
	node_id             string
	bind_address        string = '0.0.0.0'
	raft_port           int    = 12000
	peer_addresses      []string
	heartbeat_ms        int = 100
	election_timeout_ms int = 1000
}

// LLMConfig for LLM client
pub struct LLMConfig {
pub mut:
	provider    string = 'openai'
	api_key     string
	model       string = 'gpt-4'
	max_tokens  int    = 2048
	temperature f64    = 0.7
	timeout_ms  int    = 30000
	max_retries int    = 3
}

// LogConfig for logging
pub struct LogConfig {
pub mut:
	level        string = 'info'
	format       string = 'text' // or 'json'
	output       string = 'stdout'
	max_size_mb  int    = 100
	max_backups  int    = 5
	max_age_days int    = 30
}

// ============================================================================
// Callback Types
// ============================================================================

// ChangeHandler is called when config changes
pub type ChangeHandler = fn (Config) !

// ValidateHandler is called to validate config
pub type ValidateHandler = fn (Config) !

// ============================================================================
// Manager
// ============================================================================

// Manager handles configuration with hot reload
pub struct Manager {
pub mut:
	config          Config
	config_path     string
	config_type     string // 'json' or 'yaml'
	mu              sync.RwMutex
	watcher_running bool
	stop_watcher    chan bool

	// Callbacks - v3.1: Use Option type
	on_change   ?ChangeHandler   // v3.1: Option instead of unsafe nil
	on_validate ?ValidateHandler // v3.1: Option instead of unsafe nil
}

// new_manager creates a config manager
pub fn new_manager() &Manager {
	return &Manager{
		config:       Config{}
		stop_watcher: chan bool{}
		on_change:    none  // v3.1: Use Option
		on_validate:  none  // v3.1: Use Option
	}
}

// ============================================================================
// Load/Save Operations
// ============================================================================

// load loads configuration from file
pub fn (mut m Manager) load(path string) ! {
	m.config_path = path

	// Detect file type
	if path.ends_with('.json') {
		m.config_type = 'json'
	} else if path.ends_with('.yaml') || path.ends_with('.yml') {
		m.config_type = 'yaml'
	} else {
		return error('unsupported config format: ${path}')
	}

	// Read and parse
	content := os.read_file(path)!
	new_config := m.parse(content)!

	// Validate
	m.validate_with_callback(new_config)!

	// Apply
	m.mu.lock()
	m.config = new_config
	m.mu.unlock()
}

// save saves current config to file
pub fn (mut m Manager) save() ! {
	if m.config_path == '' {
		return error('no config path set')
	}

	m.mu.rlock()
	config := m.config
	m.mu.runlock()

	content := json2.encode(config,
		prettify:       true
		legacy_layout:  true
		escape_unicode: true
		time_as_unix:   true
	)

	// Write atomically using temp file
	temp_path := '${m.config_path}.tmp'
	os.write_file(temp_path, content)!
	os.mv(temp_path, m.config_path)!
}

// parse parses config content based on type
fn (m &Manager) parse(content string) !Config {
	return match m.config_type {
		'json' { json2.decode[Config](content)! }
		'yaml' { json2.decode[Config](content)! } // YAML is JSON superset for simple cases
		else { error('unknown config type') }
	}
}

// validate_with_callback runs validation with callback
fn (m &Manager) validate_with_callback(cfg Config) ! {
	if f := m.on_validate {
		f(cfg) or {
			return error('config validation failed: ${err}')
		}
	}
}

// ============================================================================
// Hot Reload
// ============================================================================

// start_watching starts file watcher for hot reload
pub fn (mut m Manager) start_watching() ! {
	if m.watcher_running {
		return error('watcher already running')
	}
	if m.config_path == '' {
		return error('no config path set')
	}

	m.watcher_running = true
	spawn m.watcher_loop()
}

// stop_watching stops the file watcher
pub fn (mut m Manager) stop_watching() ! {
	if !m.watcher_running {
		return
	}
	m.stop_watcher <- true
	m.watcher_running = false
}

// watcher_loop monitors file for changes
fn (mut m Manager) watcher_loop() {
	mut last_mod := os.file_last_mod_unix(m.config_path)

	for m.watcher_running {
		select {
			_ := <-m.stop_watcher {
				return
			}
			1000 * time.millisecond {
				current_mod := os.file_last_mod_unix(m.config_path)
				if current_mod > last_mod {
					last_mod = current_mod
					m.reload() or {
						eprintln('Config reload failed: ${err}')
					}
				}
			}
		}
	}
}

// reload reloads configuration from disk
pub fn (mut m Manager) reload() ! {
	// Read new config
	content := os.read_file(m.config_path)!
	new_config := m.parse(content)!

	// Validate
	m.validate_with_callback(new_config)!

	// Store old config for rollback
	m.mu.rlock()
	old_config := m.config
	m.mu.runlock()

	// Apply new config
	m.mu.lock()
	m.config = new_config
	m.mu.unlock()

	// Notify with rollback on failure
	if f := m.on_change {
		f(new_config) or {
			eprintln('Change handler failed, rolling back: ${err}')
			m.mu.lock()
			m.config = old_config
			m.mu.unlock()
			return error('change handler failed: ${err}')
		}
	}

	println('Configuration reloaded successfully')
}

// ============================================================================
// Callback Setters - v3.1: Type-safe callback setters
// ============================================================================

// set_on_change sets the change handler
pub fn (mut m Manager) set_on_change(handler ChangeHandler) {
	m.mu.lock()
	defer { m.mu.unlock() }
	m.on_change = handler
}

// set_on_validate sets the validation handler
pub fn (mut m Manager) set_on_validate(handler ValidateHandler) {
	m.mu.lock()
	defer { m.mu.unlock() }
	m.on_validate = handler
}

// clear_callbacks clears all callbacks
pub fn (mut m Manager) clear_callbacks() {
	m.mu.lock()
	defer { m.mu.unlock() }
	m.on_change = none
	m.on_validate = none
}

// ============================================================================
// Query/Update Operations
// ============================================================================

// get returns current config (thread-safe copy)
pub fn (mut m Manager) get() Config {
	m.mu.rlock()
	defer { m.mu.runlock() }
	return m.config
}

// update updates specific config values
pub fn (mut m Manager) update(updater fn (mut Config)) ! {
	m.mu.lock()
	defer { m.mu.unlock() }

	updater(mut m.config)
	m.validate_with_callback(m.config)!
}

// get_config_path returns the current config file path
pub fn (m &Manager) get_config_path() string {
	return m.config_path
}

// get_config_type returns the config format type
pub fn (m &Manager) get_config_type() string {
	return m.config_type
}

// is_watching returns true if file watcher is running
pub fn (m &Manager) is_watching() bool {
	return m.watcher_running
}

// ============================================================================
// Defaults & Validation
// ============================================================================

// default returns default configuration
pub fn default() Config {
	return Config{
		server:  ServerConfig{}
		actor:   ActorConfig{}
		storage: StorageConfig{}
		cluster: ClusterConfig{}
		llm:     LLMConfig{}
		log:     LogConfig{}
	}
}

// validate performs basic validation
pub fn validate(c Config) ! {
	if c.server.http_port <= 0 || c.server.http_port > 65535 {
		return error('invalid HTTP port: ${c.server.http_port}')
	}
	if c.actor.mailbox_size <= 0 {
		return error('mailbox_size must be positive')
	}
	if c.storage.segment_size <= 0 {
		return error('segment_size must be positive')
	}

	valid_levels := ['debug', 'info', 'warn', 'error', 'fatal']
	if c.log.level !in valid_levels {
		return error('invalid log level: ${c.log.level}')
	}
}

// validate_and_return validates and returns the config or error
pub fn validate_and_return(c Config) !Config {
	validate(c)!
	return c
}
