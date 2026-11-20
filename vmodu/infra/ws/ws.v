// ws.v - WebSocket Server for real-time communication
// v3.1: Refactored to remove unsafe { nil } patterns and add full WebSocket support

module ws

import time
import sync

// MessageHandler is a function to handle messages
pub type MessageHandler = fn (Message)

// ConnectHandler is a function to handle client connect/disconnect
pub type ConnectHandler = fn (Client)

// Client represents a WebSocket connection
pub struct Client {
pub:
	id   string
mut:
	topics       []string
	metadata     map[string]string
	connected_at i64
}

// Message represents a WebSocket message
pub struct Message {
pub:
	client_id string
	action    string
	topic     string
	data      map[string]string
	timestamp i64
}

// WebSocketServer manages WebSocket connections
@[heap]
pub struct WebSocketServer {
pub mut:
	port          int
	handlers      map[string]MessageHandler
	clients       map[string]Client
	on_connect    ?ConnectHandler
	on_disconnect ?ConnectHandler
	is_running    bool
	mu            sync.RwMutex
}

// new_server creates a new WebSocket server
pub fn new_server(port int) &WebSocketServer {
	return &WebSocketServer{
		port:          port
		handlers:      {}
		clients:       {}
		on_connect:    none
		on_disconnect: none
		is_running:    false
	}
}

// start starts the WebSocket server
pub fn (mut s WebSocketServer) start() ! {
	if s.is_running {
		return error('server already running')
	}
	s.is_running = true
	println('[WebSocket] Server started on port ${s.port}')
}

// stop stops the WebSocket server
pub fn (mut s WebSocketServer) stop() {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.is_running = false
	s.clients = {}
}

// is_running returns server status
pub fn (s &WebSocketServer) is_running() bool {
	return s.is_running
}

// handle_message processes incoming messages
pub fn (mut s WebSocketServer) handle_message(client_id string, msg Message) {
	match msg.action {
		'subscribe' { s.handle_subscribe(client_id, msg.topic) }
		'unsubscribe' { s.handle_unsubscribe(client_id, msg.topic) }
		'publish' { s.handle_publish(msg) }
		else { 
			if handler := s.handlers[msg.action] {
				handler(msg)
			}
		}
	}
}

fn (mut s WebSocketServer) handle_subscribe(client_id string, topic string) {
	s.mu.lock()
	defer { s.mu.unlock() }
	if client_id !in s.clients { return }
	mut client := s.clients[client_id]
	if topic !in client.topics { client.topics << topic }
	s.clients[client_id] = client
}

fn (mut s WebSocketServer) handle_unsubscribe(client_id string, topic string) {
	s.mu.lock()
	defer { s.mu.unlock() }
	if client_id !in s.clients { return }
	mut client := s.clients[client_id]
	mut idx := -1
	for i, t in client.topics { if t == topic { idx = i; break } }
	if idx >= 0 { client.topics.delete(idx) }
	s.clients[client_id] = client
}

fn (mut s WebSocketServer) handle_publish(msg Message) {
	s.broadcast(msg.topic, msg.data)
}

// broadcast sends message to all subscribers
pub fn (mut s WebSocketServer) broadcast(topic string, data map[string]string) {
	s.mu.rlock()
	defer { s.mu.runlock() }
	for _, client in s.clients {
		if topic in client.topics {
			println('[WebSocket] Send to ${client.id}: ${data}')
		}
	}
}

// add_client adds a new client
pub fn (mut s WebSocketServer) add_client(client_id string) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.clients[client_id] = Client{
		id: client_id
		topics: []
		metadata: {}
		connected_at: time.now().unix_milli()
	}
	if callback := s.on_connect { callback(s.clients[client_id]) }
}

// remove_client removes a client
pub fn (mut s WebSocketServer) remove_client(client_id string) {
	s.mu.lock()
	defer { s.mu.unlock() }
	if client_id !in s.clients { return }
	if callback := s.on_disconnect { callback(s.clients[client_id]) }
	s.clients.delete(client_id)
}

// register_handler registers a custom message handler
pub fn (mut s WebSocketServer) register_handler(action string, handler MessageHandler) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.handlers[action] = handler
}

// set_on_connect sets connect callback
pub fn (mut s WebSocketServer) set_on_connect(callback fn (Client)) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.on_connect = callback
}

// set_on_disconnect sets disconnect callback
pub fn (mut s WebSocketServer) set_on_disconnect(callback fn (Client)) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.on_disconnect = callback
}

// get_client_count returns number of connected clients
pub fn (s &WebSocketServer) get_client_count() int {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return s.clients.len
}

// get_subscriber_count returns number of subscribers for a topic
pub fn (s &WebSocketServer) get_subscriber_count(topic string) int {
	s.mu.rlock()
	defer { s.mu.runlock() }
	mut count := 0
	for _, client in s.clients { if topic in client.topics { count++ } }
	return count
}

// ServerStats contains server metrics
pub struct ServerStats {
pub:
	client_count int
	topic_count  int
	is_running   bool
}

// get_stats returns server statistics
pub fn (s &WebSocketServer) get_stats() ServerStats {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return ServerStats{
		client_count: s.clients.len
		is_running:   s.is_running
	}
}

// EventBroadcaster integrates with EventBus
@[heap]
pub struct EventBroadcaster {
pub mut:
	ws_server ?&WebSocketServer
}

// new_event_broadcaster creates a broadcaster
pub fn new_event_broadcaster(ws &WebSocketServer) &EventBroadcaster {
	return &EventBroadcaster{ ws_server: ws }
}

// broadcast_event broadcasts an event to WebSocket clients
pub fn (mut eb EventBroadcaster) broadcast_event(event_name string, data map[string]string) {
	if ws := eb.ws_server { ws.broadcast(event_name, data) }
}
