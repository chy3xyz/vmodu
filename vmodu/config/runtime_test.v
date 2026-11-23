// runtime_test.v - Unit tests for environment-based RuntimeConfig helpers
module config

fn test_parse_env_int_defaults() {
	assert parse_env_int('', 8080) == 8080
	assert parse_env_int('   ', 42) == 42
	assert parse_env_int('abc', 7) == 7
	assert parse_env_int('9090', 8080) == 9090
	assert parse_env_int('0', 99) == 0
	assert parse_env_int('-5', 1) == -5
}

fn test_parse_env_bool_accepts_common_forms() {
	assert parse_env_bool('1', false) == true
	assert parse_env_bool('0', true) == false
	assert parse_env_bool('true', false) == true
	assert parse_env_bool('FALSE', true) == false
	assert parse_env_bool('True', false) == true
	assert parse_env_bool('', true) == true
	assert parse_env_bool('', false) == false
	assert parse_env_bool('maybe', true) == true
	assert parse_env_bool('maybe', false) == false
}

fn test_runtime_config_struct_defaults() {
	c := RuntimeConfig{}
	assert c.http_host == '0.0.0.0'
	assert c.http_port == 8080
	assert c.max_connections == 1024
	assert c.rate_limit_rps == 1000
	assert c.rate_limit_burst == 200
	assert c.ip_rate_limit_rps == 100
	assert c.ip_rate_limit_burst == 50
	assert c.rate_limit_per_ip == true
	assert c.access_log == true
}

fn test_load_runtime_config_uses_defaults_when_unset() {
	// Pure defaults when vars are absent — does not assert against polluted env.
	// Helpers above cover parsing; this checks the struct wiring shape.
	c := load_runtime_config()
	assert c.http_host.len > 0
	assert c.http_port > 0
	assert c.max_connections > 0
}
