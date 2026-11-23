// raft_test.v — Raft transport wiring + durable state

module raft

import os
import rand
import vmodu.cluster.raft.rpc

fn test_request_vote_uses_memory_transport() {
	mut transport := MemoryTransport{
		grant_vote: true
	}
	mut node := new_node('n1', ['peer-a'])
	node.set_transport(mut transport)
	node.current_term = 3
	node.state = .candidate
	node.voted_for = 'n1'
	node.votes_granted = 1

	node.request_vote('peer-a', 3, 0, 0)

	assert transport.sent.len == 1
	msg := transport.sent[0]
	assert msg.msg_type == .request_vote_req
	assert msg.from == 'n1'
	assert msg.to == 'peer-a'
	assert msg.term == 3

	req := rpc.decode_request_vote_req(msg) or {
		assert false, 'decode vote req: ${err}'
		return
	}
	assert req.candidate_id == 'n1'
	assert req.term == 3
	assert req.last_log_idx == 0
}

fn test_no_transport_does_not_fake_vote() {
	mut node := new_node('n1', ['peer-a'])
	// default NilTransport — must not pretend success
	node.request_vote('peer-a', 1, 0, 0)

	select {
		_ := <-node.vote_ch {
			assert false, 'NilTransport must not deliver a vote result'
		}
		else {}
	}
}

fn test_append_entries_uses_memory_transport() {
	mut transport := MemoryTransport{
		append_success: true
	}
	mut node := new_node('n1', ['peer-a'])
	node.set_transport(mut transport)
	node.current_term = 2
	node.state = .leader
	node.next_index['peer-a'] = 1

	node.send_append_entries('peer-a', 2, 0)

	assert transport.sent.len == 1
	msg := transport.sent[0]
	assert msg.msg_type == .append_entries_req
	assert msg.from == 'n1'
	assert msg.to == 'peer-a'

	ae := rpc.decode_append_entries_req(msg) or {
		assert false, 'decode append req: ${err}'
		return
	}
	assert ae.leader_id == 'n1'
	assert ae.term == 2
	assert ae.entries.len == 0 // heartbeat
}

fn test_file_storage_roundtrip_term_vote_log() {
	path := os.join_path(os.temp_dir(), 'vmodu_raft_${rand.intn(1_000_000) or { 0 }}.json')
	defer {
		os.rm(path) or {}
		os.rm('${path}.tmp') or {}
	}

	mut storage := new_file_storage(path)
	mut node := new_node('n1', [])
	node.set_storage(mut storage)
	node.state = .leader
	node.current_term = 5
	node.voted_for = 'n1'
	node.propose('set', 'x=1') or {
		assert false, 'propose: ${err}'
		return
	}

	mut node2 := new_node('n1', [])
	mut storage2 := new_file_storage(path)
	node2.set_storage(mut storage2)
	node2.load_persistent() or {
		assert false, 'load_persistent: ${err}'
		return
	}

	assert node2.current_term == 5
	assert node2.voted_for or { '' } == 'n1'
	assert node2.log.len == 1
	assert node2.log[0].command == 'set'
	assert node2.log[0].data == 'x=1'
}

fn test_handle_vote_persists_voted_for() {
	path := os.join_path(os.temp_dir(), 'vmodu_raft_vote_${rand.intn(1_000_000) or { 0 }}.json')
	defer {
		os.rm(path) or {}
	}

	mut storage := new_file_storage(path)
	mut node := new_node('n1', [])
	node.set_storage(mut storage)

	res := node.handle_vote_request(VoteRequest{
		term:           2
		candidate_id:   'cand-a'
		last_log_index: 0
		last_log_term:  0
	})
	assert res.vote_granted == true
	assert node.current_term == 2

	mut node2 := new_node('n1', [])
	mut storage2 := new_file_storage(path)
	node2.set_storage(mut storage2)
	node2.load_persistent() or {
		assert false, 'load: ${err}'
		return
	}
	assert node2.current_term == 2
	assert node2.voted_for or { '' } == 'cand-a'
}

fn test_compact_log_persists_snapshot_and_shortens_log() {
	path := os.join_path(os.temp_dir(), 'vmodu_raft_snap_${rand.intn(1_000_000) or { 0 }}.json')
	defer {
		os.rm(path) or {}
		os.rm('${path}.tmp') or {}
	}

	mut storage := new_file_storage(path)
	mut node := new_node('n1', [])
	node.set_storage(mut storage)
	node.state = .leader
	node.current_term = 4

	node.propose('a', '1') or {
		assert false, 'propose a: ${err}'
		return
	}
	node.propose('b', '2') or {
		assert false, 'propose b: ${err}'
		return
	}
	node.propose('c', '3') or {
		assert false, 'propose c: ${err}'
		return
	}
	node.propose('d', '4') or {
		assert false, 'propose d: ${err}'
		return
	}
	assert node.log.len == 4
	assert node.last_log_index() == 4

	node.compact_log(2) or {
		assert false, 'compact_log: ${err}'
		return
	}
	assert node.snapshot_index == 2
	assert node.snapshot_term == 4
	assert node.log.len == 2
	assert node.log[0].index == 3
	assert node.log[1].index == 4
	assert node.last_log_index() == 4
	assert node.last_log_term() == 4

	// Compact away the rest — empty log must still report snapshot index/term
	node.compact_log(4) or {
		assert false, 'compact_log all: ${err}'
		return
	}
	assert node.log.len == 0
	assert node.snapshot_index == 4
	assert node.last_log_index() == 4
	assert node.last_log_term() == 4

	mut node2 := new_node('n1', [])
	mut storage2 := new_file_storage(path)
	node2.set_storage(mut storage2)
	node2.load_persistent() or {
		assert false, 'load_persistent: ${err}'
		return
	}
	assert node2.current_term == 4
	assert node2.snapshot_index == 4
	assert node2.snapshot_term == 4
	assert node2.log.len == 0
	assert node2.last_log_index() == 4
	assert node2.last_log_term() == 4

	// Vote helper: candidate with equal last index/term is up-to-date
	res := node2.handle_vote_request(VoteRequest{
		term:           5
		candidate_id:   'cand-b'
		last_log_index: 4
		last_log_term:   4
	})
	assert res.vote_granted == true

	// Append helper: heartbeat with prev at snapshot succeeds
	ae := node2.handle_append_entries(AppendEntries{
		term:           5
		leader_id:      'leader'
		prev_log_index: 4
		prev_log_term:  4
		entries:        []
		leader_commit:  4
	})
	assert ae.success == true
	assert ae.term == 5
}

fn test_wal_storage_append_only_roundtrip() {
	dir := os.join_path(os.temp_dir(), 'vmodu_raft_wal_${rand.intn(1_000_000) or { 0 }}')
	defer {
		os.rmdir_all(dir) or {}
	}

	mut wal := new_wal_storage(dir)
	assert wal.fsync_mode == .every_write
	mut node := new_node('n1', [])
	node.set_storage(mut wal)
	node.state = .leader
	node.current_term = 3
	node.voted_for = 'n1'
	node.propose('a', '1') or {
		assert false, 'propose1: ${err}'
		return
	}
	node.propose('b', '2') or {
		assert false, 'propose2: ${err}'
		return
	}

	wal_path := os.join_path(dir, 'wal.log')
	assert os.exists(wal_path)
	before := os.file_size(wal_path)

	node.propose('c', '3') or {
		assert false, 'propose3: ${err}'
		return
	}
	after := os.file_size(wal_path)
	assert after > before // append-only growth

	mut node2 := new_node('n1', [])
	mut wal2 := new_wal_storage(dir)
	node2.set_storage(mut wal2)
	node2.load_persistent() or {
		assert false, 'load: ${err}'
		return
	}
	assert node2.current_term == 3
	assert node2.log.len == 3
	assert node2.log[2].command == 'c'

	wal2.compact_wal() or {
		assert false, 'compact_wal: ${err}'
		return
	}
	assert os.file_size(wal_path) == 0
	assert os.exists(os.join_path(dir, 'snapshot.json'))

	mut node3 := new_node('n1', [])
	mut wal3 := new_wal_storage(dir)
	node3.set_storage(mut wal3)
	node3.load_persistent() or {
		assert false, 'load after compact: ${err}'
		return
	}
	assert node3.log.len == 3
}

fn test_wal_storage_fsync_none_still_loads() {
	dir := os.join_path(os.temp_dir(), 'vmodu_raft_wal_nofsync_${rand.intn(1_000_000) or { 0 }}')
	defer {
		os.rmdir_all(dir) or {}
	}

	mut wal := new_wal_storage_opts(dir, .none)
	assert wal.fsync_mode == .none
	wal.set_fsync_mode(.none) // setter still works
	mut node := new_node('n1', [])
	node.set_storage(mut wal)
	node.state = .leader
	node.current_term = 2
	node.voted_for = 'n1'
	node.propose('x', 'y') or {
		assert false, 'propose: ${err}'
		return
	}

	mut node2 := new_node('n1', [])
	mut wal2 := new_wal_storage(dir)
	node2.set_storage(mut wal2)
	node2.load_persistent() or {
		assert false, 'load: ${err}'
		return
	}
	assert node2.current_term == 2
	assert node2.log.len == 1
	assert node2.log[0].data == 'y'
}

fn test_compact_log_then_propose_continues_index() {
	mut node := new_node('n1', [])
	node.state = .leader
	node.current_term = 1
	node.propose('a', '1') or { assert false, '${err}'
		return
	}
	node.propose('b', '2') or { assert false, '${err}'
		return
	}
	node.compact_log(2) or { assert false, '${err}'
		return
	}
	assert node.log.len == 0
	node.propose('c', '3') or { assert false, '${err}'
		return
	}
	assert node.log.len == 1
	assert node.log[0].index == 3
	assert node.last_log_index() == 3
}
