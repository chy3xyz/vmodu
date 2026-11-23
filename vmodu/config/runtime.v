// runtime.v - Environment-based runtime config for the default entry
module config

import os

// RuntimeConfig holds process-level HTTP server settings loaded from env.
pub struct RuntimeConfig {
pub:
	http_host            string = '0.0.0.0'
	http_port            int    = 8080
	max_connections      int    = 1024
	rate_limit_rps       int    = 1000
	rate_limit_burst     int    = 200
	ip_rate_limit_rps    int    = 100
	ip_rate_limit_burst  int    = 50
	rate_limit_per_ip    bool   = true
	access_log           bool   = true
	trace_enabled        bool   // VMODU_TRACE=1/console enables console span export
}

// parse_env_int returns raw parsed as int, or def when empty/invalid.
pub fn parse_env_int(raw string, def int) int {
	s := raw.trim_space()
	if s.len == 0 {
		return def
	}
	for i, c in s {
		if i == 0 && (c == `-` || c == `+`) {
			if s.len == 1 {
				return def
			}
			continue
		}
		if c < `0` || c > `9` {
			return def
		}
	}
	return s.int()
}

// parse_env_bool accepts 1/0/true/false (case-insensitive). Empty/unknown => def.
pub fn parse_env_bool(raw string, def bool) bool {
	s := raw.trim_space().to_lower()
	if s.len == 0 {
		return def
	}
	return match s {
		'1', 'true', 'yes', 'on' { true }
		'0', 'false', 'no', 'off' { false }
		else { def }
	}
}

// env_or returns getenv value or def when unset/empty.
fn env_or(key string, def string) string {
	if v := os.getenv_opt(key) {
		s := v.trim_space()
		if s.len > 0 {
			return s
		}
	}
	return def
}

// load_runtime_config reads VMODU_* env vars into RuntimeConfig (defaults applied).
pub fn load_runtime_config() RuntimeConfig {
	return RuntimeConfig{
		http_host:           env_or('VMODU_HTTP_HOST', '0.0.0.0')
		http_port:           parse_env_int(os.getenv('VMODU_HTTP_PORT'), 8080)
		max_connections:     parse_env_int(os.getenv('VMODU_MAX_CONNECTIONS'), 1024)
		rate_limit_rps:      parse_env_int(os.getenv('VMODU_RATE_LIMIT_RPS'), 1000)
		rate_limit_burst:    parse_env_int(os.getenv('VMODU_RATE_LIMIT_BURST'), 200)
		ip_rate_limit_rps:   parse_env_int(os.getenv('VMODU_IP_RATE_LIMIT_RPS'), 100)
		ip_rate_limit_burst: parse_env_int(os.getenv('VMODU_IP_RATE_LIMIT_BURST'), 50)
		rate_limit_per_ip:   parse_env_bool(os.getenv('VMODU_RATE_LIMIT_PER_IP'), true)
		access_log:          parse_env_bool(os.getenv('VMODU_ACCESS_LOG'), true)
		trace_enabled:       parse_env_bool(os.getenv('VMODU_TRACE'), false)
			|| os.getenv('VMODU_TRACE').trim_space().to_lower() == 'console'
	}
}
