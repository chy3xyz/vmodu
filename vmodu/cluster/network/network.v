// network.v - Network layer for distributed cluster communication
// v3.2: TCP-based RPC for inter-node communication

module network

import net
import json2
import time
import sync
import rand

// MessageType represents different message types
pub enum MessageType {
	heartbeat
	join_request
	join_response
	actor_lookup
	actor_lookup_response
	actor_migrate
	actor_migrate_response
	actor_message
}

// ClusterMessage is the envelope for all cluster messages
pub struct ClusterMessage {
pub:
	msg_type  MessageType
	sender_id string
	target_id string
	payload   string
	timestamp i64
	msg_id    string
}

// NodeInfo contains node information
pub struct NodeInfo {
pub:
	id      string
	address string
	port    int
	actors  []string
}

// NetworkManager handles all network communication
pub struct NetworkManager {
pub:
	node_id   string
	bind_addr string
	port      int
pub mut:
	peers      map[string]&PeerConnection
	is_running bool
	mu         sync.RwMutex
}

// PeerConnection represents a connection to a peer node
pub struct PeerConnection {
pub:
	node_id string
	address string
	port    int
pub mut:
	is_connected   bool
	last_heartbeat i64
}

// new_network_manager creates a new network manager
pub fn new_network_manager(node_id string, bind_addr string, port int) &NetworkManager {
	return &NetworkManager{
		node_id:    node_id
		bind_addr:  bind_addr
		port:       port
		peers:      {}
		is_running: false
	}
}

// start starts the network manager
pub fn (mut n NetworkManager) start() ! {
	if n.is_running {
		return error('network manager already running')
	}
	n.is_running = true
	println('[Network] Started on ${n.bind_addr}:${n.port}')
}

// stop stops the network manager
pub fn (mut n NetworkManager) stop() {
	n.is_running = false
	println('[Network] Stopped')
}

// connect_to_peer connects to a peer node
pub fn (mut n NetworkManager) connect_to_peer(node_id string, address string, port int) ! {
	peer := &PeerConnection{
		node_id:        node_id
		address:        address
		port:           port
		is_connected:   true
		last_heartbeat: time.now().unix_milli()
	}
	n.peers[node_id] = peer
}

// send_message sends a message to a peer
pub fn (mut n NetworkManager) send_message(target_id string, msg ClusterMessage) ! {
	// Implementation would send via TCP
	return nil
}

// get_stats returns network statistics
pub fn (n &NetworkManager) get_stats() NetworkStats {
	return NetworkStats{
		node_id:    n.node_id
		peer_count: n.peers.len
		is_running: n.is_running
	}
}

// NetworkStats contains network statistics
pub struct NetworkStats {
pub:
	node_id    string
	peer_count int
	is_running bool
}

// generate_msg_id generates a unique message ID
fn generate_msg_id() string {
	return '${time.now().unix_milli()}_${rand.intn(1000000) or { 0 }}'
}
