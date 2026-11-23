// persist.v — durable Raft state (term, voted_for, log) for wave-2 hardening.
// Not a full WAL/snapshot store; atomic JSON file rewrite is the durability model.

module raft

import json2
import os

// DurableState is the subset Raft must survive process restart (Raft paper §5.2).
// snapshot_* fields are optional (wave-3); missing on load => 0 / empty (no snapshot).
pub struct DurableState {
pub mut:
	current_term   int
	voted_for      string // empty means none
	log            []LogEntry
	snapshot_index int    // last included index; 0 = none
	snapshot_term  int    // term of entry at snapshot_index
	snapshot_data  string // opaque app state; empty = none
}

// Storage persists DurableState. NilStorage keeps in-memory-only nodes (tests/default).
pub interface Storage {
mut:
	load() !DurableState
	save(state DurableState) !
}

pub struct NilStorage {}

pub fn (mut s NilStorage) load() !DurableState {
	return DurableState{}
}

pub fn (mut s NilStorage) save(_ DurableState) ! {}

// FileStorage rewrites a single JSON file atomically (tmp + rename).
pub struct FileStorage {
pub:
	path string
}

pub fn new_file_storage(path string) FileStorage {
	return FileStorage{
		path: path
	}
}

pub fn (mut s FileStorage) load() !DurableState {
	if !os.exists(s.path) {
		return DurableState{}
	}
	raw := os.read_file(s.path)!
	if raw.trim_space().len == 0 {
		return DurableState{}
	}
	return json2.decode[DurableState](raw)!
}

pub fn (mut s FileStorage) save(state DurableState) ! {
	dir := os.dir(s.path)
	if dir.len > 0 && !os.exists(dir) {
		os.mkdir_all(dir)!
	}
	payload := json2.encode(state, escape_unicode: true)
	tmp := '${s.path}.tmp'
	os.write_file(tmp, payload)!
	os.mv(tmp, s.path)!
}
