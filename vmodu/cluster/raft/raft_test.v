// raft_test.v — Raft transport wiring (no simulated sleep votes)

module raft

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
