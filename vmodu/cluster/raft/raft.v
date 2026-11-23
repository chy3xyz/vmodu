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

	// Snapshot (compacted prefix); log holds only entries with index > snapshot_index
	snapshot_index  int
	snapshot_term   int
	snapshot_data   string

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

	// Durable state (term / voted_for / log / snapshot); default NilStorage = memory only
	storage         Storage   = NilStorage{}

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
		storage:      NilStorage{}
	}
}

// set_transport injects an outbound RPC transport (rpc.Client or MemoryTransport)
pub fn (mut n RaftNode) set_transport(mut t Transport) {
	n.mu.lock()
	defer { n.mu.unlock() }
	n.transport = t
}

// set_storage injects durable storage (call before start / load_persistent)
pub fn (mut n RaftNode) set_storage(mut s Storage) {
	n.mu.lock()
	defer { n.mu.unlock() }
	n.storage = s
}

// load_persistent restores term, voted_for, log, and snapshot from storage
pub fn (mut n RaftNode) load_persistent() ! {
	n.mu.lock()
	defer { n.mu.unlock() }
	state := n.storage.load()!
	n.current_term = state.current_term
	if state.voted_for.len > 0 {
		n.voted_for = state.voted_for
	} else {
		n.voted_for = none
	}
	n.snapshot_index = state.snapshot_index
	n.snapshot_term = state.snapshot_term
	n.snapshot_data = state.snapshot_data
	// Keep only entries after snapshot (defensive if older files were inconsistent)
	mut kept := []LogEntry{}
	for e in state.log {
		if e.index > state.snapshot_index {
			kept << e
		}
	}
	n.log = kept
}

// persist_locked writes durable state; caller must hold n.mu
fn (mut n RaftNode) persist_locked() {
	voted := n.voted_for or { '' }
	state := DurableState{
		current_term:   n.current_term
		voted_for:      voted
		log:            n.log.clone()
		snapshot_index: n.snapshot_index
		snapshot_term:  n.snapshot_term
		snapshot_data:  n.snapshot_data
	}
	n.storage.save(state) or {
		eprintln('[Raft] persist failed for ${n.id}: ${err}')
	}
}

// last_log_index returns the Raft index of the last log entry, or snapshot_index if log is empty.
pub fn (n &RaftNode) last_log_index() int {
	if n.log.len > 0 {
		return n.log[n.log.len - 1].index
	}
	return n.snapshot_index
}

// last_log_term returns the term of the last log entry, or snapshot_term if log is empty.
pub fn (n &RaftNode) last_log_term() int {
	if n.log.len > 0 {
		return n.log[n.log.len - 1].term
	}
	return n.snapshot_term
}

// log_array_index maps a Raft log index to a position in n.log (-1 if not present).
fn (n &RaftNode) log_array_index(raft_index int) int {
	if raft_index <= n.snapshot_index {
		return -1
	}
	ai := raft_index - n.snapshot_index - 1
	if ai < 0 || ai >= n.log.len {
		return -1
	}
	return ai
}

// term_at returns the term at raft_index (snapshot or log). ok=false if unknown.
fn (n &RaftNode) term_at(raft_index int) (int, bool) {
	if raft_index == 0 {
		return 0, true
	}
	if raft_index == n.snapshot_index {
		return n.snapshot_term, true
	}
	ai := n.log_array_index(raft_index)
	if ai < 0 {
		return 0, false
	}
	return n.log[ai].term, true
}

// compact_log truncates durable log entries with index <= through_index into a snapshot.
// snapshot_data is left empty (use install_snapshot to supply opaque state).
pub fn (mut n RaftNode) compact_log(through_index int) ! {
	n.mu.lock()
	defer { n.mu.unlock() }
	n.compact_log_locked(through_index, '')!
}

// install_snapshot records a snapshot covering indices 1..=last_included_index and
// drops matching prefix from the in-memory log. Persists via Storage.
pub fn (mut n RaftNode) install_snapshot(last_included_index int, last_included_term int, data string) ! {
	n.mu.lock()
	defer { n.mu.unlock() }
	if last_included_index < n.snapshot_index {
		return error('install_snapshot: index ${last_included_index} behind existing snapshot ${n.snapshot_index}')
	}
	n.snapshot_index = last_included_index
	n.snapshot_term = last_included_term
	n.snapshot_data = data
	mut kept := []LogEntry{}
	for e in n.log {
		if e.index > last_included_index {
			kept << e
		}
	}
	n.log = kept
	if n.last_applied < last_included_index {
		n.last_applied = last_included_index
	}
	if n.commit_index < last_included_index {
		n.commit_index = last_included_index
	}
	n.persist_locked()
}

fn (mut n RaftNode) compact_log_locked(through_index int, data string) ! {
	if through_index <= n.snapshot_index {
		return error('compact_log: through_index ${through_index} <= snapshot_index ${n.snapshot_index}')
	}
	last := n.last_log_index()
	if through_index > last {
		return error('compact_log: through_index ${through_index} > last_log_index ${last}')
	}
	term, ok := n.term_at(through_index)
	if !ok {
		return error('compact_log: no term for index ${through_index}')
	}
	n.snapshot_index = through_index
	n.snapshot_term = term
	if data.len > 0 {
		n.snapshot_data = data
	}
	mut kept := []LogEntry{}
	for e in n.log {
		if e.index > through_index {
			kept << e
		}
	}
	n.log = kept
	if n.last_applied < through_index {
		n.last_applied = through_index
	}
	if n.commit_index < through_index {
		n.commit_index = through_index
	}
	n.persist_locked()
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
	n.persist_locked()
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
	next := n.last_log_index() + 1
	for peer in n.peers {
		n.next_index[peer] = next
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
	n.persist_locked()
	n.reset_election_timer()
}

// start_election starts a new election
fn (mut n RaftNode) start_election() {
	n.mu.lock()
	n.votes_granted = 1 // self-vote
	term := n.current_term
	last_log_index := n.last_log_index()
	last_log_term := n.last_log_term()
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
	mut next_idx := n.next_index[peer] or { n.snapshot_index + 1 }
	if next_idx <= n.snapshot_index {
		next_idx = n.snapshot_index + 1
	}
	prev_log_index := next_idx - 1
	prev_log_term, _ := n.term_at(prev_log_index)

	mut entries := []LogEntry{}
	ai := n.log_array_index(next_idx)
	if ai >= 0 {
		entries = n.log[ai..]
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
	mut dirty := false
	if req.term > n.current_term {
		n.current_term = req.term
		n.voted_for = none
		n.state = .follower
		dirty = true
	}
	
	// Check if we can vote for this candidate
	voted := n.voted_for or { '' }
	can_vote := voted.len == 0 || voted == req.candidate_id

	// Check if candidate's log is at least as up-to-date as ours
	last_log_index := n.last_log_index()
	last_log_term := n.last_log_term()

	log_is_up_to_date := req.last_log_term > last_log_term ||
		(req.last_log_term == last_log_term && req.last_log_index >= last_log_index)
	
	if can_vote && log_is_up_to_date {
		n.voted_for = req.candidate_id
		n.reset_election_timer()
		n.persist_locked()
		return VoteResult{term: n.current_term, vote_granted: true, node_id: n.id}
	}

	if dirty {
		n.persist_locked()
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
	mut dirty := false
	if req.term > n.current_term || n.state != .follower {
		n.current_term = req.term
		n.voted_for = none
		n.state = .follower
		dirty = true
	}
	
	n.reset_election_timer()

	last_idx := n.last_log_index()

	// Check prev log entry (respect snapshot)
	if req.prev_log_index > 0 {
		if req.prev_log_index > last_idx {
			if dirty {
				n.persist_locked()
			}
			return AppendResult{term: n.current_term, success: false, node_id: n.id, match_index: last_idx}
		}
		if req.prev_log_index < n.snapshot_index {
			if dirty {
				n.persist_locked()
			}
			return AppendResult{term: n.current_term, success: false, node_id: n.id, match_index: n.snapshot_index}
		}
		pt, ok := n.term_at(req.prev_log_index)
		if !ok || pt != req.prev_log_term {
			if dirty {
				n.persist_locked()
			}
			return AppendResult{term: n.current_term, success: false, node_id: n.id, match_index: req.prev_log_index - 1}
		}
	}

	// Append new entries (array offset = raft_index - snapshot_index - 1)
	if req.entries.len > 0 {
		for i, entry in req.entries {
			raft_idx := req.prev_log_index + 1 + i
			if raft_idx <= n.snapshot_index {
				continue
			}
			ai := raft_idx - n.snapshot_index - 1
			if ai < n.log.len {
				if n.log[ai].term != entry.term {
					n.log = n.log[..ai]
					n.log << entry
					dirty = true
				}
			} else {
				n.log << entry
				dirty = true
			}
		}
	}

	// Update commit index (volatile — not required on disk for this wave)
	if req.leader_commit > n.commit_index {
		n.commit_index = req.leader_commit
		lli := n.last_log_index()
		if lli < n.commit_index {
			n.commit_index = lli
		}
	}

	if dirty {
		n.persist_locked()
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
		index:   n.last_log_index() + 1
		command: command
		data:    data
	}
	
	n.log << entry
	n.persist_locked()
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
