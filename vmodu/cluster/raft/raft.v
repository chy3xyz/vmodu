// raft.v - Raft Consensus Implementation for VModulith Runtime
// v3.2: Complete Raft consensus with Leader Election and Log Replication

module raft

import time
import sync
import rand
import vmodu.cluster.raft.rpc

// Transport abstracts outbound Raft RPCs (real rpc.Client or in-memory fake).
pub interface Transport {
mut:
	send(peer_id string, msg rpc.Message) !rpc.Response
}

// NilTransport fails clearly when no transport is configured.
pub struct NilTransport {}

pub fn (mut t NilTransport) send(peer_id string, msg rpc.Message) !rpc.Response {
	return error('raft: no transport configured (refusing simulated success)')
}

// MemoryTransport records outbound RPCs and returns configurable replies (for tests).
pub struct MemoryTransport {
pub mut:
	sent              []rpc.Message
	grant_vote        bool = true
	append_success    bool = true
	response_term     int  // 0 => echo request term
}

pub fn (mut t MemoryTransport) send(peer_id string, msg rpc.Message) !rpc.Response {
	t.sent << msg
	term := if t.response_term > 0 { t.response_term } else { msg.term }
	match msg.msg_type {
		.request_vote_req {
			resp := rpc.RequestVoteResponse{
				term:         term
				vote_granted: t.grant_vote
			}
			return rpc.Response{
				message: rpc.new_request_vote_resp(peer_id, msg.from, term, resp)
				err:     ''
			}
		}
		.append_entries_req, .heartbeat {
			ae := rpc.decode_append_entries_req(msg) or {
				rpc.AppendEntriesRequest{}
			}
			match_idx := ae.prev_log_idx + ae.entries.len
			resp := rpc.AppendEntriesResponse{
				term:      term
				success:   t.append_success
				match_idx: match_idx
				next_idx:  match_idx + 1
			}
			return rpc.Response{
				message: rpc.new_append_entries_resp(peer_id, msg.from, term, resp)
				err:     ''
			}
		}
		else {
			return error('memory transport: unsupported message type ${msg.msg_type}')
		}
	}
}

// NodeState represents the state of a Raft node
pub enum NodeState {
	follower
	candidate
	leader
}

// LogEntry represents a single entry in the Raft log
pub struct LogEntry {
pub:
	term    int
	index   int
	command string
	data    string
}

// RaftNode implements the Raft consensus algorithm
pub struct RaftNode {
pub:
	id       string
	peers    []string  // List of peer node addresses
	election_timeout_min int = 150  // milliseconds
	election_timeout_max int = 300  // milliseconds
	heartbeat_interval   int = 50   // milliseconds
pub mut:
	state           NodeState
	current_term    int
	voted_for       ?string
	log             []LogEntry
	commit_index    int
	last_applied    int
	
	// Leader state
	next_index      map[string]int
	match_index     map[string]int
	
	// Election
	votes_granted   int
	
	// Timers
	election_timer  i64
	heartbeat_timer i64
	
	// Channels
	vote_ch         chan VoteResult
	append_ch       chan AppendResult
	
	// Control
	is_running      bool
	mu              sync.RwMutex
	
	// Outbound RPC (rpc.Client implements Transport)
	transport       Transport = NilTransport{}
	
	// Callbacks
	on_leader_elected ?fn ()
	on_commit         ?fn (LogEntry)
}

// VoteResult represents the result of a vote request
pub struct VoteResult {
pub:
	term        int
	vote_granted bool
	node_id     string
}

// AppendResult represents the result of an append entries request
pub struct AppendResult {
pub:
	term         int
	success      bool
	node_id      string
	match_index  int
}

// VoteRequest is sent during leader election
pub struct VoteRequest {
pub:
	term         int
	candidate_id string
	last_log_index int
	last_log_term  int
}

// AppendEntries is sent by leader to replicate log entries
pub struct AppendEntries {
pub:
	term         int
	leader_id    string
	prev_log_index int
	prev_log_term  int
	entries      []LogEntry
	leader_commit  int
}

// new_node creates a new Raft node (outbound RPCs fail until set_transport is called)
pub fn new_node(id string, peers []string) &RaftNode {
	return &RaftNode{
		id:       id
		peers:    peers
		state:    .follower
		current_term: 0
		voted_for: none
		log:      []
		commit_index: 0
		last_applied: 0
		next_index:   {}
		match_index:  {}
		votes_granted: 0
		is_running:   false
		vote_ch:      chan VoteResult{cap: 64}
		append_ch:    chan AppendResult{cap: 64}
		transport:    NilTransport{}
	}
}

// set_transport injects an outbound RPC transport (rpc.Client or MemoryTransport)
pub fn (mut n RaftNode) set_transport(mut t Transport) {
	n.mu.lock()
	defer { n.mu.unlock() }
	n.transport = t
}

// start starts the Raft node
pub fn (mut n RaftNode) start() {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	if n.is_running {
		return
	}
	
	n.is_running = true
	n.reset_election_timer()
	
	// Start the main loop
	spawn n.run()
	
	println('[Raft] Node ${n.id} started')
}

// stop stops the Raft node
pub fn (mut n RaftNode) stop() {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	n.is_running = false
	println('[Raft] Node ${n.id} stopped')
}

// run is the main Raft event loop
fn (mut n RaftNode) run() {
	for n.is_running {
		match n.state {
			.follower  { n.run_follower() }
			.candidate { n.run_candidate() }
			.leader    { n.run_leader() }
		}
		time.sleep(10 * time.millisecond)
	}
}

// run_follower runs the follower logic
fn (mut n RaftNode) run_follower() {
	now := time.now().unix_milli()
	
	n.mu.lock()
	timeout := n.election_timer
	n.mu.unlock()
	
	if now > timeout {
		// Election timeout, convert to candidate
		println('[Raft] Node ${n.id} election timeout, converting to candidate')
		n.become_candidate()
	}
}

// run_candidate runs the candidate logic
fn (mut n RaftNode) run_candidate() {
	// Check if election timeout has passed
	now := time.now().unix_milli()
	
	n.mu.lock()
	timeout := n.election_timer
	n.mu.unlock()
	
	if now > timeout {
		// Start new election
		n.start_election()
	}
	
	// Check for election result
	select {
		result := <-n.vote_ch {
			if result.vote_granted {
				n.check_election_won()
			}
		}
		else {}
	}
}

// run_leader runs the leader logic
fn (mut n RaftNode) run_leader() {
	now := time.now().unix_milli()
	
	n.mu.lock()
	heartbeat_due := now > n.heartbeat_timer
	n.mu.unlock()
	
	if heartbeat_due {
		n.send_heartbeats()
		n.mu.lock()
		n.heartbeat_timer = now + i64(n.heartbeat_interval)
		n.mu.unlock()
	}
}

// become_candidate converts to candidate state
fn (mut n RaftNode) become_candidate() {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	n.state = .candidate
	n.current_term++
	n.voted_for = n.id
	n.reset_election_timer()
	
	println('[Raft] Node ${n.id} became candidate for term ${n.current_term}')
	
	// Vote for self
	n.start_election()
}

// become_leader converts to leader state
fn (mut n RaftNode) become_leader() {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	n.state = .leader
	
	// Initialize leader state
	for peer in n.peers {
		n.next_index[peer] = n.log.len + 1
		n.match_index[peer] = 0
	}
	
	n.heartbeat_timer = 0  // Send heartbeat immediately
	
	println('[Raft] Node ${n.id} became leader for term ${n.current_term}')
	
	// Trigger callback
	if cb := n.on_leader_elected {
		cb()
	}
}

// become_follower converts to follower state
fn (mut n RaftNode) become_follower(term int) {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	n.state = .follower
	n.current_term = term
	n.voted_for = none
	n.reset_election_timer()
}

// start_election starts a new election
fn (mut n RaftNode) start_election() {
	n.mu.lock()
	n.votes_granted = 1 // self-vote
	term := n.current_term
	last_log_index := n.log.len
	last_log_term := if n.log.len > 0 { n.log[n.log.len - 1].term } else { 0 }
	peers := n.peers.clone()
	n.mu.unlock()

	if peers.len == 0 {
		n.become_leader()
		return
	}

	// Request votes from all peers via transport
	for peer in peers {
		spawn n.request_vote(peer, term, last_log_index, last_log_term)
	}
}

// request_vote sends a vote request to a peer through Transport
fn (mut n RaftNode) request_vote(peer string, term int, last_log_index int, last_log_term int) {
	rv_req := rpc.RequestVoteRequest{
		term:          term
		candidate_id:  n.id
		last_log_idx:  last_log_index
		last_log_term: last_log_term
	}
	msg := rpc.new_request_vote_req(n.id, peer, term, rv_req)

	resp := n.transport.send(peer, msg) or {
		eprintln('[Raft] vote request to ${peer} failed: ${err}')
		return
	}
	if resp.err.len > 0 {
		eprintln('[Raft] vote request to ${peer} error: ${resp.err}')
		return
	}

	vote_resp := rpc.decode_request_vote_resp(resp.message) or {
		eprintln('[Raft] decode vote response from ${peer}: ${err}')
		return
	}

	if vote_resp.term > term {
		n.become_follower(vote_resp.term)
		return
	}

	result := VoteResult{
		term:         vote_resp.term
		vote_granted: vote_resp.vote_granted
		node_id:      peer
	}
	n.vote_ch <- result
}

// check_election_won checks if we have won the election
fn (mut n RaftNode) check_election_won() {
	n.mu.lock()
	n.votes_granted++
	votes := n.votes_granted
	needed := (n.peers.len + 1) / 2 + 1
	is_candidate := n.state == .candidate
	n.mu.unlock()

	if is_candidate && votes >= needed {
		n.become_leader()
	}
}

// send_heartbeats sends heartbeat to all peers
fn (mut n RaftNode) send_heartbeats() {
	n.mu.lock()
	term := n.current_term
	leader_commit := n.commit_index
	n.mu.unlock()
	
	for peer in n.peers {
		spawn n.send_append_entries(peer, term, leader_commit)
	}
}

// send_append_entries sends append entries / heartbeat to a peer through Transport
fn (mut n RaftNode) send_append_entries(peer string, term int, leader_commit int) {
	n.mu.lock()
	next_idx := n.next_index[peer] or { 1 }
	prev_log_index := next_idx - 1
	prev_log_term := if prev_log_index > 0 && prev_log_index <= n.log.len {
		n.log[prev_log_index - 1].term
	} else {
		0
	}

	mut entries := []LogEntry{}
	if next_idx <= n.log.len {
		entries = n.log[next_idx - 1..]
	}
	n.mu.unlock()

	mut rpc_entries := []rpc.LogEntry{}
	for e in entries {
		rpc_entries << rpc.LogEntry{
			term:    e.term
			index:   e.index
			command: e.command
		}
	}

	ae_req := rpc.AppendEntriesRequest{
		term:          term
		leader_id:     n.id
		prev_log_idx:  prev_log_index
		prev_log_term: prev_log_term
		entries:       rpc_entries
		leader_commit: leader_commit
	}
	msg := rpc.new_append_entries_req(n.id, peer, term, ae_req)

	resp := n.transport.send(peer, msg) or {
		eprintln('[Raft] append entries to ${peer} failed: ${err}')
		return
	}
	if resp.err.len > 0 {
		eprintln('[Raft] append entries to ${peer} error: ${resp.err}')
		return
	}

	ae_resp := rpc.decode_append_entries_resp(resp.message) or {
		eprintln('[Raft] decode append response from ${peer}: ${err}')
		return
	}

	if ae_resp.term > term {
		n.become_follower(ae_resp.term)
		return
	}

	if ae_resp.success {
		n.mu.lock()
		n.match_index[peer] = ae_resp.match_idx
		n.next_index[peer] = ae_resp.match_idx + 1
		n.mu.unlock()
	}

	result := AppendResult{
		term:        ae_resp.term
		success:     ae_resp.success
		node_id:     peer
		match_index: ae_resp.match_idx
	}
	n.append_ch <- result
}

// handle_vote_request handles incoming vote requests
pub fn (mut n RaftNode) handle_vote_request(req VoteRequest) VoteResult {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	// Reply false if term < currentTerm
	if req.term < n.current_term {
		return VoteResult{term: n.current_term, vote_granted: false, node_id: n.id}
	}
	
	// If term > currentTerm, convert to follower
	if req.term > n.current_term {
		n.current_term = req.term
		n.voted_for = none
		n.state = .follower
	}
	
	// Check if we can vote for this candidate
	can_vote := n.voted_for == none || n.voted_for == req.candidate_id
	
	// Check if candidate's log is at least as up-to-date as ours
	last_log_index := n.log.len
	last_log_term := if n.log.len > 0 { n.log[n.log.len - 1].term } else { 0 }
	
	log_is_up_to_date := req.last_log_term > last_log_term || 
		(req.last_log_term == last_log_term && req.last_log_index >= last_log_index)
	
	if can_vote && log_is_up_to_date {
		n.voted_for = req.candidate_id
		n.reset_election_timer()
		return VoteResult{term: n.current_term, vote_granted: true, node_id: n.id}
	}
	
	return VoteResult{term: n.current_term, vote_granted: false, node_id: n.id}
}

// handle_append_entries handles incoming append entries
pub fn (mut n RaftNode) handle_append_entries(req AppendEntries) AppendResult {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	// Reply false if term < currentTerm
	if req.term < n.current_term {
		return AppendResult{term: n.current_term, success: false, node_id: n.id, match_index: 0}
	}
	
	// If term >= currentTerm, convert to follower
	if req.term > n.current_term || n.state != .follower {
		n.current_term = req.term
		n.voted_for = none
		n.state = .follower
	}
	
	n.reset_election_timer()
	
	// Check prev log entry
	if req.prev_log_index > 0 {
		if req.prev_log_index > n.log.len {
			return AppendResult{term: n.current_term, success: false, node_id: n.id, match_index: n.log.len}
		}
		if req.prev_log_index > 0 && n.log[req.prev_log_index - 1].term != req.prev_log_term {
			return AppendResult{term: n.current_term, success: false, node_id: n.id, match_index: req.prev_log_index - 1}
		}
	}
	
	// Append new entries
	if req.entries.len > 0 {
		// Remove conflicting entries and append new ones
		for i, entry in req.entries {
			idx := req.prev_log_index + i
			if idx < n.log.len {
				if n.log[idx].term != entry.term {
					n.log = n.log[..idx]
					n.log << entry
				}
			} else {
				n.log << entry
			}
		}
	}
	
	// Update commit index
	if req.leader_commit > n.commit_index {
		n.commit_index = req.leader_commit
		if n.log.len < n.commit_index {
			n.commit_index = n.log.len
		}
	}
	
	return AppendResult{
		term:        n.current_term
		success:     true
		node_id:     n.id
		match_index: req.prev_log_index + req.entries.len
	}
}

// propose proposes a new command (must be called on leader)
pub fn (mut n RaftNode) propose(command string, data string) ! {
	n.mu.lock()
	defer { n.mu.unlock() }
	
	if n.state != .leader {
		return error('not the leader')
	}
	
	entry := LogEntry{
		term:    n.current_term
		index:   n.log.len + 1
		command: command
		data:    data
	}
	
	n.log << entry
	println('[Raft] Proposed command at index ${entry.index}')
}

// get_state returns current state
pub fn (n &RaftNode) get_state() NodeState {
	return n.state
}

// get_term returns current term
pub fn (n &RaftNode) get_term() int {
	return n.current_term
}

// is_leader returns true if this node is the leader
pub fn (n &RaftNode) is_leader() bool {
	return n.state == .leader
}

// reset_election_timer resets the election timer
fn (mut n RaftNode) reset_election_timer() {
	span := n.election_timeout_max - n.election_timeout_min
	jitter := if span > 0 { rand.intn(span) or { 0 } } else { 0 }
	timeout := n.election_timeout_min + jitter
	n.election_timer = time.now().unix_milli() + i64(timeout)
}

// RaftStats contains node statistics
pub struct RaftStats {
pub:
	id            string
	state         string
	term          int
	log_size      int
	commit_index  int
	last_applied  int
	is_leader     bool
}

// get_stats returns node statistics
pub fn (n &RaftNode) get_stats() RaftStats {
	n.mu.rlock()
	defer { n.mu.runlock() }
	
	return RaftStats{
		id:           n.id
		state:        n.state.str()
		term:         n.current_term
		log_size:     n.log.len
		commit_index: n.commit_index
		last_applied: n.last_applied
		is_leader:    n.state == .leader
	}
}

// str returns string representation of NodeState
pub fn (s NodeState) str() string {
	return match s {
		.follower  { 'follower' }
		.candidate { 'candidate' }
		.leader    { 'leader' }
	}
}
