// infra/logger/logger.v
// Structured logging with multiple output formats
// v3.1: Refactored to remove unsafe { nil } patterns
// Features:
// - JSON and text output formats
// - Log levels (debug, info, warn, error, fatal)
// - Structured fields support
// - File and stdout outputs
// - Log rotation support

module logger

import os
import time
import sync
import json2

// Level represents log severity
pub enum Level {
	debug = 0
	info  = 1
	warn  = 2
	error = 3
	fatal = 4
}

// String returns level name
pub fn (l Level) str() string {
	return match l {
		.debug { 'DEBUG' }
		.info { 'INFO' }
		.warn { 'WARN' }
		.error { 'ERROR' }
		.fatal { 'FATAL' }
	}
}

// Format for log output
pub enum Format {
	text
	json
}

// Config for logger
pub struct Config {
pub mut:
	level          Level  = .info
	format         Format = .text
	output         string = 'stdout' // 'stdout', 'stderr', or file path
	add_timestamp  bool   = true
	add_caller     bool   = false
	rotation_size  i64    = 100 * 1024 * 1024 // 100MB
	rotation_count int    = 5
}

// Fields for structured logging
pub type Fields = map[string]string

// Logger is the main logging interface
pub struct Logger {
pub mut:
	config        Config
	file          os.File
	mu            sync.Mutex
	bytes_written i64
	initialized   bool // v3.1: Track initialization state
}

// Entry represents a single log entry
struct Entry {
	timestamp string
	level     string
	message   string
	fields    map[string]string
	caller    string
}

// new creates a new Logger
pub fn new(config Config) !&Logger {
	mut l := &Logger{
		config:      config
		initialized: true  // v3.1: Mark as initialized
	}

	// Open output file if specified
	if config.output != 'stdout' && config.output != 'stderr' {
		l.file = os.open_append(config.output)!
	}

	return l
}

// default creates a Logger with default config
pub fn default() &Logger {
	return new(Config{}) or {
		// Fallback to stdout on error
		eprintln('Failed to create logger: ${err}')
		new(Config{ output: 'stdout' }) or { panic(err) }
	}
}

// log writes a log entry
fn (mut l Logger) log(level Level, message string, fields map[string]string) {
	// Check level
	if int(level) < int(l.config.level) {
		return
	}

	// Build entry
	mut entry := Entry{
		timestamp: if l.config.add_timestamp { time.now().format_rfc3339() } else { '' }
		level:     level.str()
		message:   message
		fields:    fields.clone()
		caller:    if l.config.add_caller { get_caller() } else { '' }
	}

	// Format output
	output := match l.config.format {
		.text { l.format_text(entry) }
		.json { l.format_json(entry) }
	}

	// Write output
	l.mu.lock()
	defer { l.mu.unlock() }

	if l.config.output == 'stdout' {
		println(output)
	} else if l.config.output == 'stderr' {
		eprintln(output)
	} else {
		l.file.writeln(output) or {
			eprintln('Failed to write to log file: ${err}')
			return
		}

		l.bytes_written += i64(output.len + 1)

		// Check rotation
		if l.bytes_written >= l.config.rotation_size {
			l.rotate() or {
				eprintln('Failed to rotate log: ${err}')
			}
		}
	}

	// Fatal logs should exit
	if level == .fatal {
		exit(1)
	}
}

// format_text formats entry as text
fn (l &Logger) format_text(entry Entry) string {
	mut parts := []string{}

	if entry.timestamp != '' {
		parts << '[${entry.timestamp}]'
	}

	parts << '[${entry.level}]'
	parts << entry.message

	// Add fields
	if entry.fields.len > 0 {
		mut field_parts := []string{}
		for key, value in entry.fields {
			field_parts << '${key}=${value}'
		}
		parts << '{' + field_parts.join(' ') + '}'
	}

	if entry.caller != '' {
		parts << '(${entry.caller})'
	}

	return parts.join(' ')
}

// format_json formats entry as JSON
fn (l &Logger) format_json(entry Entry) string {
	mut obj := map[string]string{}

	if entry.timestamp != '' {
		obj['timestamp'] = entry.timestamp
	}
	obj['level'] = entry.level
	obj['message'] = entry.message

	for key, value in entry.fields {
		obj[key] = value
	}

	if entry.caller != '' {
		obj['caller'] = entry.caller
	}

	return json2.encode(obj, escape_unicode: true, time_as_unix: true)
}

// rotate rotates the log file
fn (mut l Logger) rotate() ! {
	// Close current file
	l.file.close()

	// Rotate existing files
	for i := l.config.rotation_count - 1; i > 0; i-- {
		old_path := '${l.config.output}.${i}'
		new_path := '${l.config.output}.${i + 1}'

		if os.exists(old_path) {
			if os.exists(new_path) {
				os.rm(new_path)!
			}
			os.mv(old_path, new_path)!
		}
	}

	// Move current to .1
	os.mv(l.config.output, '${l.config.output}.1')!

	// Open new file
	l.file = os.open_append(l.config.output)!
	l.bytes_written = 0
}

// get_caller returns caller information (simplified)
fn get_caller() string {
	// In production, use runtime.Callers or equivalent
	// For now, return empty
	return ''
}

// Debug logs a debug message
pub fn (mut l Logger) debug(msg string) {
	l.log(.debug, msg, {})
}

// debug_with_fields logs with structured fields
pub fn (mut l Logger) debug_with_fields(msg string, fields Fields) {
	l.log(.debug, msg, fields)
}

// Info logs an info message
pub fn (mut l Logger) info(msg string) {
	l.log(.info, msg, {})
}

// info_with_fields logs with structured fields
pub fn (mut l Logger) info_with_fields(msg string, fields Fields) {
	l.log(.info, msg, fields)
}

// Warn logs a warning message
pub fn (mut l Logger) warn(msg string) {
	l.log(.warn, msg, {})
}

// warn_with_fields logs with structured fields
pub fn (mut l Logger) warn_with_fields(msg string, fields Fields) {
	l.log(.warn, msg, fields)
}

// Error logs an error message
pub fn (mut l Logger) error(msg string) {
	l.log(.error, msg, {})
}

// error_with_fields logs with structured fields
pub fn (mut l Logger) error_with_fields(msg string, fields Fields) {
	l.log(.error, msg, fields)
}

// Fatal logs a fatal message and exits
pub fn (mut l Logger) fatal(msg string) {
	l.log(.fatal, msg, {})
}

// fatal_with_fields logs with structured fields and exits
pub fn (mut l Logger) fatal_with_fields(msg string, fields Fields) {
	l.log(.fatal, msg, fields)
}

// close closes the logger
pub fn (mut l Logger) close() ! {
	if l.config.output != 'stdout' && l.config.output != 'stderr' {
		l.file.close()
	}
	l.initialized = false
}

// SetLevel changes the log level at runtime
pub fn (mut l Logger) set_level(level Level) {
	l.mu.lock()
	defer { l.mu.unlock() }
	l.config.level = level
}

// GetLevel returns current log level
pub fn (l &Logger) get_level() Level {
	return l.config.level
}

// IsInitialized returns true if logger is initialized
pub fn (l &Logger) is_initialized() bool {
	return l.initialized
}

// ========== Global Logger ==========

// v3.1: Use Option type instead of unsafe nil
__global global_logger ?&Logger = none

// init_global_logger initializes the global logger
pub fn init_global_logger(config Config) ! {
	logger := new(config)!
	global_logger = logger
}

// get_global_logger returns the global logger instance
pub fn get_global_logger() &Logger {
	if logger := global_logger {
		return logger
	}
	// Auto-initialize with default
	logger := default()
	global_logger = logger
	return logger
}

// is_global_logger_initialized returns true if global logger is initialized
pub fn is_global_logger_initialized() bool {
	return global_logger != none
}

// reset_global_logger resets the global logger (useful for testing)
pub fn reset_global_logger() {
	global_logger = none
}

// Convenience functions for global logger
pub fn debug(msg string) {
	mut l := get_global_logger()
	l.debug(msg)
}

pub fn info(msg string) {
	mut l := get_global_logger()
	l.info(msg)
}

pub fn warn(msg string) {
	mut l := get_global_logger()
	l.warn(msg)
}

pub fn error(msg string) {
	mut l := get_global_logger()
	l.error(msg)
}

pub fn fatal(msg string) {
	mut l := get_global_logger()
	l.fatal(msg)
}

pub fn debug_with_fields(msg string, fields Fields) {
	mut l := get_global_logger()
	l.debug_with_fields(msg, fields)
}

pub fn info_with_fields(msg string, fields Fields) {
	mut l := get_global_logger()
	l.info_with_fields(msg, fields)
}

pub fn warn_with_fields(msg string, fields Fields) {
	mut l := get_global_logger()
	l.warn_with_fields(msg, fields)
}

pub fn error_with_fields(msg string, fields Fields) {
	mut l := get_global_logger()
	l.error_with_fields(msg, fields)
}

pub fn fatal_with_fields(msg string, fields Fields) {
	mut l := get_global_logger()
	l.fatal_with_fields(msg, fields)
}
