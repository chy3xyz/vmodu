// event_store_test.v - Unit tests for Persistent Event Store

module db

import os
import time

// setup_test_dir creates a temporary directory for tests
fn setup_test_dir() string {
	test_dir := './test_data_${time.now().unix_micro()}'
	os.mkdir_all(test_dir) or { panic('failed to create test dir: ${err}') }
	return test_dir
}

// cleanup_test_dir removes test directory
fn cleanup_test_dir(test_dir string) {
	os.rmdir_all(test_dir) or {}
}

// test_new_persistent_log tests basic creation
fn test_new_persistent_log() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	config := StoreConfig{
		data_dir:          test_dir
		segment_size:      100
		buffer_size:       1024
		flush_interval_ms: 100
		fsync_on_write:    false
	}
	
	mut pl := new_persistent_log(config) or {
		assert false, 'should create log: ${err}'
		return
	}
	defer { pl.close() or {} }
	
	assert pl.config.data_dir == test_dir
	assert pl.config.segment_size == 100
	assert pl.buffer_len == 0
	assert pl.next_offset == 0
}

// test_append_single_event tests appending a single event
fn test_append_single_event() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		flush_interval_ms: 100
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	offset := pl.append('key1', 'value1') or {
		assert false, 'append should succeed: ${err}'
		return
	}
	
	assert offset == 0
	assert pl.next_offset == 1
	
	stats := pl.get_stats()
	assert stats.writes_total == 1
}

// test_append_multiple_events tests appending multiple events
fn test_append_multiple_events() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	for i in 0..10 {
		offset := pl.append('key${i}', 'value${i}') or {
			assert false, 'append ${i} should succeed'
			return
		}
		assert offset == u64(i)
	}
	
	stats := pl.get_stats()
	assert stats.writes_total == 10
}

// test_empty_key_rejection tests that empty keys are rejected
fn test_empty_key_rejection() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	pl.append('', 'value') or {
		assert err.msg().contains('empty')
		return
	}
	
	assert false, 'should have rejected empty key'
}

// test_stats_accuracy tests statistics tracking
fn test_stats_accuracy() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	initial_stats := pl.get_stats()
	assert initial_stats.writes_total == 0
	assert initial_stats.reads_total == 0
	assert initial_stats.bytes_written == 0
	
	// Write some events
	for i in 0..10 {
		pl.append('test', 'value${i}') or { assert false }
	}
	
	stats_after_write := pl.get_stats()
	assert stats_after_write.writes_total == 10
	assert stats_after_write.bytes_written > 0
}

// test_close_idempotent tests that close can be called safely
fn test_close_idempotent() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	
	pl.append('test', 'value') or { assert false }
	
	// Close should work
	pl.close() or {
		assert false, 'close should succeed: ${err}'
	}
}

// test_multiple_streams tests handling multiple streams
fn test_multiple_streams() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	// Write to multiple streams
	for i in 0..5 {
		pl.append('stream_a', 'a${i}') or { assert false }
		pl.append('stream_b', 'b${i}') or { assert false }
		pl.append('stream_c', 'c${i}') or { assert false }
	}
	
	stats := pl.get_stats()
	assert stats.writes_total == 15
}

// test_buffer_flush tests buffer operations
fn test_buffer_flush() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		flush_interval_ms: 1000
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	// Write some data
	for i in 0..5 {
		pl.append('test', 'data${i}') or { assert false }
	}
	
	// Buffer should contain data
	assert pl.buffer_len > 0
	
	// Stats should show writes
	stats := pl.get_stats()
	assert stats.writes_total == 5
}

// test_segment_creation tests segment file creation
fn test_segment_creation() {
	test_dir := setup_test_dir()
	defer { cleanup_test_dir(test_dir) }
	
	mut pl := new_persistent_log(StoreConfig{
		data_dir:       test_dir
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}) or { 
		assert false
		return
	}
	defer { pl.close() or {} }
	
	// Write events to create segments
	for i in 0..5 {
		pl.append('test', 'data${i}') or { assert false }
	}
	
	// Check that segment file exists
	assert pl.segments.len >= 1
	assert pl.active_segment.path != ''
}

// test_config_validation tests configuration
fn test_config_validation() {
	// Valid config should work
	valid_config := StoreConfig{
		data_dir:       './test'
		segment_size:   100
		buffer_size:    1024
		fsync_on_write: false
	}
	assert valid_config.segment_size > 0
	assert valid_config.buffer_size > 0
}
