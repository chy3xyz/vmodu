// config_test.v - Unit tests for Configuration

module config

// test_default_config tests default configuration values
fn test_default_config() {
	c := default()
	
	// Server defaults
	assert c.server.http_port == 8080
	assert c.server.grpc_port == 9090
	assert c.server.host == '0.0.0.0'
	assert c.server.read_timeout == 30
	assert c.server.write_timeout == 30
	
	// Actor defaults
	assert c.actor.mailbox_size == 100
	assert c.actor.worker_pool_size == 16
	assert c.actor.max_actors == 10000
	
	// Storage defaults
	assert c.storage.data_dir == './data'
	assert c.storage.segment_size == 10000
	assert c.storage.buffer_size == 8192
	assert c.storage.flush_interval_ms == 100
	assert c.storage.fsync_on_write == true
	
	// Cluster defaults
	assert c.cluster.bind_address == '0.0.0.0'
	assert c.cluster.raft_port == 12000
	assert c.cluster.peer_addresses.len == 0
	assert c.cluster.heartbeat_ms == 100
	
	// LLM defaults
	assert c.llm.provider == 'openai'
	assert c.llm.model == 'gpt-4'
	assert c.llm.max_tokens == 2048
	
	// Log defaults
	assert c.log.level == 'info'
	assert c.log.format == 'text'
	assert c.log.output == 'stdout'
}

// test_validate_valid tests validation of valid config
fn test_validate_valid() {
	c := default()
	
	validate(c) or {
		assert false, 'valid config should pass: ${err}'
		return
	}
}

// test_validate_invalid_port tests validation of invalid port
fn test_validate_invalid_port() {
	mut c := default()
	c.server.http_port = 0
	
	validate(c) or {
		assert err.msg().contains('port')
		return
	}
	
	assert false, 'should fail with invalid port'
}

// test_validate_negative_port tests negative port
fn test_validate_negative_port() {
	mut c := default()
	c.server.http_port = -1
	
	validate(c) or {
		assert err.msg().contains('port')
		return
	}
	
	assert false, 'should fail with negative port'
}

// test_validate_invalid_mailbox tests invalid mailbox size
fn test_validate_invalid_mailbox() {
	mut c := default()
	c.actor.mailbox_size = 0
	
	validate(c) or {
		assert err.msg().contains('mailbox')
		return
	}
	
	assert false, 'should fail with invalid mailbox size'
}

// test_validate_invalid_segment tests invalid segment size
fn test_validate_invalid_segment() {
	mut c := default()
	c.storage.segment_size = 0
	
	validate(c) or {
		assert err.msg().contains('segment')
		return
	}
	
	assert false, 'should fail with invalid segment size'
}

// test_validate_invalid_log_level tests invalid log level
fn test_validate_invalid_log_level() {
	mut c := default()
	c.log.level = 'invalid'
	
	validate(c) or {
		assert err.msg().contains('log level')
		return
	}
	
	assert false, 'should fail with invalid log level'
}

// test_validate_valid_log_levels tests valid log levels
fn test_validate_valid_log_levels() {
	valid_levels := ['debug', 'info', 'warn', 'error', 'fatal']
	
	for level in valid_levels {
		mut c := default()
		c.log.level = level
		
		validate(c) or {
			assert false, 'level ${level} should be valid'
		}
	}
}

// test_new_manager tests manager creation
fn test_new_manager() {
	mgr := new_manager()
	
	assert mgr.config == Config{}
	assert mgr.config_path == ''
	assert mgr.config_type == ''
	assert mgr.watcher_running == false
}

// test_config_equality tests config comparison
fn test_config_equality() {
	c1 := default()
	c2 := default()
	
	assert c1 == c2
	
	mut c3 := default()
	c3.server.http_port = 9999
	
	assert c1 != c3
}

// test_server_config_defaults tests server config
fn test_server_config_defaults() {
	s := ServerConfig{}
	
	assert s.http_port == 8080
	assert s.grpc_port == 9090
	assert s.host == '0.0.0.0'
}

// test_actor_config_defaults tests actor config
fn test_actor_config_defaults() {
	a := ActorConfig{}
	
	assert a.mailbox_size == 100
	assert a.worker_pool_size == 16
	assert a.max_actors == 10000
}

// test_storage_config_defaults tests storage config
fn test_storage_config_defaults() {
	s := StorageConfig{}
	
	assert s.data_dir == './data'
	assert s.segment_size == 10000
	assert s.buffer_size == 8192
	assert s.fsync_on_write == true
}

// test_cluster_config_defaults tests cluster config
fn test_cluster_config_defaults() {
	c := ClusterConfig{}
	
	assert c.bind_address == '0.0.0.0'
	assert c.raft_port == 12000
	assert c.heartbeat_ms == 100
	assert c.election_timeout_ms == 1000
}

// test_llm_config_defaults tests LLM config
fn test_llm_config_defaults() {
	l := LLMConfig{}
	
	assert l.provider == 'openai'
	assert l.model == 'gpt-4'
	assert l.max_tokens == 2048
	assert l.temperature == 0.7
}

// test_log_config_defaults tests log config
fn test_log_config_defaults() {
	l := LogConfig{}
	
	assert l.level == 'info'
	assert l.format == 'text'
	assert l.output == 'stdout'
}

// test_config_clone tests cloning config
fn test_config_clone() {
	original := default()
	
	mut clone := original
	clone.server.http_port = 9999
	
	// Original should be unchanged
	assert original.server.http_port == 8080
	assert clone.server.http_port == 9999
}

// test_config_update tests config updates
fn test_config_update() {
	mut c := default()
	
	// Update multiple fields
	c.server.http_port = 3000
	c.actor.mailbox_size = 200
	c.storage.segment_size = 5000
	c.llm.model = 'gpt-3.5-turbo'
	c.log.level = 'debug'
	
	// Verify updates
	assert c.server.http_port == 3000
	assert c.actor.mailbox_size == 200
	assert c.storage.segment_size == 5000
	assert c.llm.model == 'gpt-3.5-turbo'
	assert c.log.level == 'debug'
}

// test_peer_addresses tests peer addresses configuration
fn test_peer_addresses() {
	mut c := default()
	
	c.cluster.peer_addresses = [
		'node-1:192.168.1.1:12000'
		'node-2:192.168.1.2:12000'
	]
	
	assert c.cluster.peer_addresses.len == 2
	assert c.cluster.peer_addresses[0] == 'node-1:192.168.1.1:12000'
}

// test_config_struct_sizes tests struct initialization
fn test_config_struct_sizes() {
	// Test that all structs can be initialized
	_ := ServerConfig{}
	_ := ActorConfig{}
	_ := StorageConfig{}
	_ := ClusterConfig{}
	_ := LLMConfig{}
	_ := LogConfig{}
	
	assert true
}
