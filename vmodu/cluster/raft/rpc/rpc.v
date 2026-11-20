// cluster/raft/rpc/rpc.v
// TCP-based Raft RPC implementation
// Implements:
// - AppendEntries RPC
// - RequestVote RPC
// - Connection pooling
// - Request/response serialization

module rpc

import net
import time
import json2
import sync
import rand

// MessageType identifies RPC message types
pub enum MessageType {
	append_entries_req
	append_entries_resp
	request_vote_req
	request_vote_resp
	heartbeat
}

// RPC message envelope
pub struct Message {
pub:
	msg_type   MessageType @[json: 'type']
	term       int         @[json: 'term']
	from       string      @[json: 'from']
	to         string      @[json: 'to']
	payload    string      @[json: 'payload'] // JSON-encoded inner message
	timestamp  i64         @[json: 'timestamp']
	request_id string      @[json: 'request_id']
}

// AppendEntriesRequest for log replication
pub struct AppendEntriesRequest {
pub:
	term          int        @[json: 'term']
	leader_id     string     @[json: 'leader_id']
	prev_log_idx  int        @[json: 'prev_log_idx']
	prev_log_term int        @[json: 'prev_log_term']
	entries       []LogEntry @[json: 'entries']
	leader_commit int        @[json: 'leader_commit']
}

// AppendEntriesResponse
pub struct AppendEntriesResponse {
pub:
	term      int  @[json: 'term']
	success   bool @[json: 'success']
	match_idx int  @[json: 'match_idx']
	next_idx  int  @[json: 'next_idx']
}

// RequestVoteRequest for leader election
pub struct RequestVoteRequest {
pub:
	term          int    @[json: 'term']
	candidate_id  string @[json: 'candidate_id']
	last_log_idx  int    @[json: 'last_log_idx']
	last_log_term int    @[json: 'last_log_term']
}

// RequestVoteResponse
pub struct RequestVoteResponse {
pub:
	term         int  @[json: 'term']
	vote_granted bool @[json: 'vote_granted']
}

// LogEntry represents a single log entry
pub struct LogEntry {
pub:
	term    int    @[json: 'term']
	index   int    @[json: 'index']
	command string @[json: 'command']
}

// RPC handler function type
pub type RPCHandler = fn (Message) !Response

// Response wrapper for async handling
pub struct Response {
pub:
	message Message
	err     string
}

// Server handles incoming RPC requests
pub struct Server {
pub mut:
	id       string
	address  string
	port     int
	listener net.TcpListener
	handlers map[MessageType]RPCHandler
	mu       sync.RwMutex
	running  bool
	config   ServerConfig
}

// ServerConfig for RPC server
pub struct ServerConfig {
pub mut:
	read_timeout_ms  int = 5000
	write_timeout_ms int = 5000
	max_message_size int = 1024 * 1024 // 1MB
	workers          int = 10
}

// new_server creates a new RPC server
pub fn new_server(id string, address string, port int, config ServerConfig) !&Server {
	return &Server{
		id:       id
		address:  address
		port:     port
		handlers: {}
		config:   config
	}
}

// register_handler registers a handler for a message type
pub fn (mut s Server) register_handler(msg_type MessageType, handler RPCHandler) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.handlers[msg_type] = handler
}

// start begins listening for connections
pub fn (mut s Server) start() ! {
	s.running = true
	s.listener = net.listen_tcp(.ip, ':${s.port}')!

	// Spawn acceptor goroutine
	spawn s.accept_loop()
}

// accept_loop accepts incoming connections
fn (mut s Server) accept_loop() {
	for s.running {
		mut conn := s.listener.accept() or {
			if s.running {
				eprintln('Accept error: ${err}')
				time.sleep(100 * time.millisecond)
			}
			continue
		}

		// Handle connection in new goroutine
		spawn s.handle_connection(mut conn)
	}
}

// handle_connection processes RPC requests from a connection
fn (mut s Server) handle_connection(mut conn net.TcpConn) {
	defer { conn.close() or {} }

	for s.running {
		// Set read timeout
		conn.set_read_timeout(s.config.read_timeout_ms * time.millisecond)

		// Read message length (4 bytes)
		mut len_buf := []u8{len: 4}
		conn.read(mut len_buf) or {
			return // Connection closed or error
		}

		msg_len := int(len_buf[0]) | (int(len_buf[1]) << 8) | (int(len_buf[2]) << 16) | (int(len_buf[3]) << 24)

		if msg_len <= 0 || msg_len > s.config.max_message_size {
			eprintln('Invalid message length: ${msg_len}')
			return
		}

		// Read message body
		mut msg_buf := []u8{len: msg_len}
		mut bytes_read := 0
		for bytes_read < msg_len {
			n := conn.read(mut msg_buf[bytes_read..]) or {
				return
			}
			bytes_read += n
		}

		// Parse message
		msg := json2.decode[Message](msg_buf.bytestr()) or {
			eprintln('Failed to decode message: ${err}')
			continue
		}

		// Handle message
		s.mu.rlock()
		handler := s.handlers[msg.msg_type]
		s.mu.runlock()

		if handler != nil {
			resp := handler(msg) or {
				Response{
					message: Message{}
					err:     err.msg()
				}
			}

			// Send response
			if resp.message.msg_type != unsafe { MessageType(0) } {
				s.send_response(mut conn, resp.message)
			}
		}
	}
}

// send_response sends an RPC response
fn (mut s Server) send_response(mut conn net.TcpConn, msg Message) {
	conn.set_write_timeout(s.config.write_timeout_ms * time.millisecond)

	resp_data := json2.encode(msg, escape_unicode: true, time_as_unix: true)
	resp_bytes := resp_data.bytes()

	// Write length prefix
	len_bytes := [
		u8(resp_bytes.len & 0xFF),
		u8((resp_bytes.len >> 8) & 0xFF),
		u8((resp_bytes.len >> 16) & 0xFF),
		u8((resp_bytes.len >> 24) & 0xFF),
	]

	conn.write(len_bytes) or { return }
	conn.write(resp_bytes) or { return }
}

// stop shuts down the server
pub fn (mut s Server) stop() ! {
	s.running = false
	s.listener.close()!
}

// Client for sending RPC requests
pub struct Client {
pub mut:
	id     string
	peers  map[string]PeerConn
	config ClientConfig
	mu     sync.RwMutex
}

// PeerConn represents a connection to a peer
pub struct PeerConn {
pub mut:
	id        string
	address   string
	port      int
	conn      net.TcpConn
	connected bool
	last_used i64
}

// ClientConfig for RPC client
pub struct ClientConfig {
pub mut:
	dial_timeout_ms    int  = 5000
	request_timeout_ms int  = 10000
	keep_alive         bool = true
}

// new_client creates a new RPC client
pub fn new_client(id string, config ClientConfig) &Client {
	return &Client{
		id:     id
		peers:  {}
		config: config
	}
}

// add_peer registers a peer
pub fn (mut c Client) add_peer(id string, address string, port int) {
	c.mu.lock()
	defer { c.mu.unlock() }

	c.peers[id] = PeerConn{
		id:      id
		address: address
		port:    port
	}
}

// remove_peer unregisters a peer
pub fn (mut c Client) remove_peer(id string) {
	c.mu.lock()
	defer { c.mu.unlock() }

	if id in c.peers {
		mut peer := c.peers[id]
		if peer.connected {
			peer.conn.close() or {}
		}
		c.peers.delete(id)
	}
}

// send sends an RPC request to a peer
pub fn (mut c Client) send(peer_id string, msg Message) !Response {
	c.mu.lock()
	mut peer := c.peers[peer_id] or {
		c.mu.unlock()
		return error('unknown peer: ${peer_id}')
	}
	c.mu.unlock()

	// Connect if not connected
	if !peer.connected {
		conn := net.dial_tcp('${peer.address}:${peer.port}') or {
			return error('failed to connect to ${peer_id}: ${err}')
		}
		peer.conn = conn
		peer.connected = true

		c.mu.lock()
		c.peers[peer_id] = peer
		c.mu.unlock()
	}

	// Serialize message
	msg_data := json2.encode(msg, escape_unicode: true, time_as_unix: true)
	msg_bytes := msg_data.bytes()

	// Write length prefix
	len_bytes := [
		u8(msg_bytes.len & 0xFF),
		u8((msg_bytes.len >> 8) & 0xFF),
		u8((msg_bytes.len >> 16) & 0xFF),
		u8((msg_bytes.len >> 24) & 0xFF),
	]

	peer.conn.set_write_timeout(c.config.request_timeout_ms * time.millisecond)
	peer.conn.write(len_bytes) or {
		peer.connected = false
		return error('write error: ${err}')
	}
	peer.conn.write(msg_bytes) or {
		peer.connected = false
		return error('write error: ${err}')
	}

	// Read response (if expecting one)
	peer.conn.set_read_timeout(c.config.request_timeout_ms * time.millisecond)

	mut resp_len_buf := []u8{len: 4}
	peer.conn.read(mut resp_len_buf) or {
		peer.connected = false
		return error('read error: ${err}')
	}

	resp_len := int(resp_len_buf[0]) | (int(resp_len_buf[1]) << 8) | (int(resp_len_buf[2]) << 16) | (int(resp_len_buf[3]) << 24)

	mut resp_buf := []u8{len: resp_len}
	mut bytes_read := 0
	for bytes_read < resp_len {
		n := peer.conn.read(mut resp_buf[bytes_read..]) or {
			peer.connected = false
			return error('read error: ${err}')
		}
		bytes_read += n
	}

	resp_msg := json2.decode[Message](resp_buf.bytestr()) or {
		return error('decode error: ${err}')
	}

	// Update last used
	peer.last_used = time.now().unix_milli()
	c.mu.lock()
	c.peers[peer_id] = peer
	c.mu.unlock()

	return Response{
		message: resp_msg
		err:     ''
	}
}

// send_all sends a message to all peers
pub fn (mut c Client) send_all(msg Message) map[string]Response {
	c.mu.rlock()
	peer_ids := c.peers.keys()
	c.mu.runlock()

	mut results := map[string]Response{}

	for peer_id in peer_ids {
		results[peer_id] = c.send(peer_id, msg) or {
			Response{
				message: Message{}
				err:     err.msg()
			}
		}
	}

	return results
}

// close closes all peer connections
pub fn (mut c Client) close() {
	c.mu.lock()
	defer { c.mu.unlock() }

	for _, mut peer in c.peers {
		if peer.connected {
			peer.conn.close() or {}
			peer.connected = false
		}
	}
	c.peers = {}
}

// Utility functions for creating messages
pub fn new_append_entries_req(from string, to string, term int, req AppendEntriesRequest) Message {
	return Message{
		msg_type:   .append_entries_req
		term:       term
		from:       from
		to:         to
		payload:    json2.encode(req, escape_unicode: true, time_as_unix: true)
		timestamp:  time.now().unix_milli()
		request_id: generate_request_id()
	}
}

pub fn new_append_entries_resp(from string, to string, term int, resp AppendEntriesResponse) Message {
	return Message{
		msg_type:   .append_entries_resp
		term:       term
		from:       from
		to:         to
		payload:    json2.encode(resp, escape_unicode: true, time_as_unix: true)
		timestamp:  time.now().unix_milli()
		request_id: generate_request_id()
	}
}

pub fn new_request_vote_req(from string, to string, term int, req RequestVoteRequest) Message {
	return Message{
		msg_type:   .request_vote_req
		term:       term
		from:       from
		to:         to
		payload:    json2.encode(req, escape_unicode: true, time_as_unix: true)
		timestamp:  time.now().unix_milli()
		request_id: generate_request_id()
	}
}

pub fn new_request_vote_resp(from string, to string, term int, resp RequestVoteResponse) Message {
	return Message{
		msg_type:   .request_vote_resp
		term:       term
		from:       from
		to:         to
		payload:    json2.encode(resp, escape_unicode: true, time_as_unix: true)
		timestamp:  time.now().unix_milli()
		request_id: generate_request_id()
	}
}

fn generate_request_id() string {
	return '${time.now().unix_milli()}_${rand.intn(1000000) or { 0 }}'
}

// decode_append_entries_req decodes payload
pub fn decode_append_entries_req(msg Message) !AppendEntriesRequest {
	return json2.decode[AppendEntriesRequest](msg.payload)
}

// decode_append_entries_resp decodes payload
pub fn decode_append_entries_resp(msg Message) !AppendEntriesResponse {
	return json2.decode[AppendEntriesResponse](msg.payload)
}

// decode_request_vote_req decodes payload
pub fn decode_request_vote_req(msg Message) !RequestVoteRequest {
	return json2.decode[RequestVoteRequest](msg.payload)
}

// decode_request_vote_resp decodes payload
pub fn decode_request_vote_resp(msg Message) !RequestVoteResponse {
	return json2.decode[RequestVoteResponse](msg.payload)
}
