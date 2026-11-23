// wal.v — append-only Raft WAL (wave 4). Hot path appends; optional compact rewrites.

module raft

import json2
import os

// WalFsyncMode controls durability after each append_frame write.
// every_write (default): flush stdio buffer via File.flush() for production honesty.
// none: skip flush — faster for tests / when durability is handled elsewhere.
pub enum WalFsyncMode {
	none
	every_write
}

// WalFrame is one line in the WAL (JSON).
pub struct WalFrame {
pub mut:
	op             string // meta | append | truncate
	current_term   int
	voted_for      string
	snapshot_index int
	snapshot_term  int
	snapshot_data  string
	entries        []LogEntry
	truncate_to    int // for truncate: keep entries with index > truncate_to
}

// WalStorage appends frames to `wal.log` under `dir`. Never rewrites on save().
pub struct WalStorage {
pub:
	dir string
pub mut:
	fsync_mode WalFsyncMode = .every_write
mut:
	last   DurableState
	loaded bool
}

pub fn new_wal_storage(dir string) WalStorage {
	return WalStorage{
		dir: dir
	}
}

pub fn new_wal_storage_opts(dir string, fsync_mode WalFsyncMode) WalStorage {
	return WalStorage{
		dir:        dir
		fsync_mode: fsync_mode
	}
}

pub fn (mut s WalStorage) set_fsync_mode(mode WalFsyncMode) {
	s.fsync_mode = mode
}

fn (s &WalStorage) wal_path() string {
	return os.join_path(s.dir, 'wal.log')
}

fn (s &WalStorage) meta_path() string {
	return os.join_path(s.dir, 'snapshot.json')
}

pub fn (mut s WalStorage) load() !DurableState {
	if !os.exists(s.dir) {
		s.last = DurableState{}
		s.loaded = true
		return DurableState{}
	}

	mut state := DurableState{}
	// Optional compacted base snapshot (written only by compact())
	if os.exists(s.meta_path()) {
		raw := os.read_file(s.meta_path())!
		if raw.trim_space().len > 0 {
			state = json2.decode[DurableState](raw)!
		}
	}

	if os.exists(s.wal_path()) {
		text := os.read_file(s.wal_path())!
		for line in text.split_into_lines() {
			trimmed := line.trim_space()
			if trimmed.len == 0 {
				continue
			}
			frame := json2.decode[WalFrame](trimmed)!
			state = apply_wal_frame(state, frame)
		}
	}

	s.last = clone_durable(state)
	s.loaded = true
	return state
}

fn clone_durable(state DurableState) DurableState {
	return DurableState{
		current_term:   state.current_term
		voted_for:      state.voted_for
		log:            state.log.clone()
		snapshot_index: state.snapshot_index
		snapshot_term:  state.snapshot_term
		snapshot_data:  state.snapshot_data
	}
}

fn apply_wal_frame(state DurableState, frame WalFrame) DurableState {
	mut s := clone_durable(state)
	match frame.op {
		'meta' {
			s.current_term = frame.current_term
			s.voted_for = frame.voted_for
			s.snapshot_index = frame.snapshot_index
			s.snapshot_term = frame.snapshot_term
			s.snapshot_data = frame.snapshot_data
		}
		'append' {
			s.entries_append(frame.entries)
		}
		'truncate' {
			s.current_term = frame.current_term
			s.voted_for = frame.voted_for
			s.snapshot_index = frame.snapshot_index
			s.snapshot_term = frame.snapshot_term
			s.snapshot_data = frame.snapshot_data
			mut kept := []LogEntry{}
			for e in s.log {
				if e.index > frame.truncate_to {
					kept << e
				}
			}
			s.log = kept
			if frame.entries.len > 0 {
				s.entries_append(frame.entries)
			}
		}
		else {}
	}
	return s
}

fn (mut s DurableState) entries_append(entries []LogEntry) {
	for e in entries {
		s.log << e
	}
}

fn (mut s WalStorage) ensure_loaded() ! {
	if !s.loaded {
		s.load()!
	}
}

fn (mut s WalStorage) append_frame(frame WalFrame) ! {
	if !os.exists(s.dir) {
		os.mkdir_all(s.dir)!
	}
	line := json2.encode(frame, escape_unicode: true)
	path := s.wal_path()
	mut f := os.open_append(path)!
	defer {
		f.close()
	}
	f.write_string(line + '\n')!
	// V 0.5.2 File.flush() = C.fflush (stdio); no File.fsync API — matches event_store.
	if s.fsync_mode == .every_write {
		f.flush()
	}
}

// save appends a delta frame (or truncate) — does not rewrite wal.log.
pub fn (mut s WalStorage) save(state DurableState) ! {
	s.ensure_loaded()!
	prev := s.last

	meta_changed := prev.current_term != state.current_term || prev.voted_for != state.voted_for
		|| prev.snapshot_index != state.snapshot_index || prev.snapshot_term != state.snapshot_term
		|| prev.snapshot_data != state.snapshot_data

	// Detect prefix divergence / truncation
	mut diverged := false
	if state.log.len < prev.log.len {
		diverged = true
	} else {
		for i, e in prev.log {
			if i >= state.log.len || state.log[i].index != e.index || state.log[i].term != e.term
				|| state.log[i].command != e.command || state.log[i].data != e.data {
				diverged = true
				break
			}
		}
	}

	if diverged || (meta_changed && state.snapshot_index != prev.snapshot_index) {
		s.append_frame(WalFrame{
			op:             'truncate'
			current_term:   state.current_term
			voted_for:      state.voted_for
			snapshot_index: state.snapshot_index
			snapshot_term:  state.snapshot_term
			snapshot_data:  state.snapshot_data
			truncate_to:    state.snapshot_index
			entries:        state.log.clone()
		})!
	} else {
		if meta_changed {
			s.append_frame(WalFrame{
				op:             'meta'
				current_term:   state.current_term
				voted_for:      state.voted_for
				snapshot_index: state.snapshot_index
				snapshot_term:  state.snapshot_term
				snapshot_data:  state.snapshot_data
			})!
		}
		if state.log.len > prev.log.len {
			s.append_frame(WalFrame{
				op:      'append'
				entries: state.log[prev.log.len..].clone()
			})!
		}
	}

	s.last = clone_durable(state)
}

// compact_wal writes a base snapshot.json and truncates wal.log (maintenance).
pub fn (mut s WalStorage) compact_wal() ! {
	state := s.load()!
	if !os.exists(s.dir) {
		os.mkdir_all(s.dir)!
	}
	payload := json2.encode(state, escape_unicode: true)
	tmp := s.meta_path() + '.tmp'
	os.write_file(tmp, payload)!
	os.mv(tmp, s.meta_path())!
	os.write_file(s.wal_path(), '')!
	s.last = clone_durable(state)
	s.loaded = true
}
