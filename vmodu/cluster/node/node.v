// node.v - Distributed Actor Cluster Node
// Manages actor distribution across multiple nodes

module node

import time

// NodeState represents the state of a cluster node
pub enum NodeState {
	follower
	candidate
	leader
	offline
}

// Node represents a cluster node
pub struct Node {
pub:
	id        string
	address   string
	port      int
	raft_port int
pub mut:
	state          NodeState
	actors         map[string]RemoteActor
	last_heartbeat i64
	health_score   int
}

// RemoteActor represents an actor on a remote node
pub struct RemoteActor {
pub:
	id       string
	actor_id string
	node_id  string
}

// LocalActorRef is a reference to local actor
pub struct LocalActorRef {
pub:
	actor_id string
	node_id  string
}

// Message is a cluster message
pub struct Message {
pub:
	sender   string
	receiver string
	payload  string
}

// ClusterStats contains cluster statistics
pub struct ClusterStats {
pub:
	node_count   int
	local_actors int
	total_actors int
	leader_id    string
}

// new_node creates a new cluster node
pub fn new_node(id string, address string, port int) Node {
	return Node{
		id:             id
		address:        address
		port:           port
		raft_port:      port + 1000
		state:          .follower
		actors:         {}
		last_heartbeat: time.now().unix_milli()
		health_score:   100
	}
}

// update_heartbeat updates the last heartbeat timestamp
pub fn (mut n Node) update_heartbeat() {
	n.last_heartbeat = time.now().unix_milli()
}

// is_healthy checks if node is healthy (heartbeat within timeout)
pub fn (n &Node) is_healthy(timeout_ms i64) bool {
	return time.now().unix_milli() - n.last_heartbeat < timeout_ms
}

// add_actor adds an actor reference to this node
pub fn (mut n Node) add_actor(ra RemoteActor) {
	n.actors[ra.actor_id] = ra
}

// remove_actor removes an actor from this node
pub fn (mut n Node) remove_actor(actor_id string) {
	n.actors.delete(actor_id)
}

// get_actor retrieves an actor by ID
pub fn (n &Node) get_actor(actor_id string) ?RemoteActor {
	return n.actors[actor_id] or { return none }
}

// set_state updates node state
pub fn (mut n Node) set_state(state NodeState) {
	n.state = state
}

// is_leader checks if node is leader
pub fn (n &Node) is_leader() bool {
	return n.state == .leader
}

// Cluster manages the distributed actor cluster
pub struct Cluster {
pub:
	node_id   string
	bind_addr string
	bind_port int
pub mut:
	nodes        map[string]Node
	local_actors map[string]LocalActorRef
	is_running   bool
}

// new_cluster creates a new cluster
pub fn new_cluster(node_id string, bind_addr string, bind_port int) Cluster {
	return Cluster{
		node_id:      node_id
		bind_addr:    bind_addr
		bind_port:    bind_port
		nodes:        {}
		local_actors: {}
		is_running:   false
	}
}

// start starts the cluster node
pub fn (mut c Cluster) start() ! {
	// Start cluster listener in background
	spawn fn (mut c Cluster) {
		c.listen_for_peers()
	}(mut c)

	// Start heartbeat in background
	spawn fn (mut c Cluster) {
		c.send_heartbeats()
	}(mut c)

	c.is_running = true
}

// stop stops the cluster node
pub fn (mut c Cluster) stop() {
	c.is_running = false
}

// join joins an existing cluster
pub fn (mut c Cluster) join(seed_node string, seed_port int) ! {
	println('Joining cluster via ${seed_node}:${seed_port}')

	// Create seed node reference
	seed := Node{
		id:      'seed'
		address: seed_node
		port:    seed_port
	}
	c.nodes['seed'] = seed

	// Sync actor locations
	c.sync_actor_locations()!
}

// add_local_actor registers a local actor
pub fn (mut c Cluster) add_local_actor(actor_id string) {
	c.local_actors[actor_id] = LocalActorRef{
		actor_id: actor_id
		node_id:  c.node_id
	}
}

// remove_local_actor removes a local actor
pub fn (mut c Cluster) remove_local_actor(actor_id string) {
	c.local_actors.delete(actor_id)
}

// find_actor_node finds which node hosts an actor
pub fn (c &Cluster) find_actor_node(actor_id string) ?string {
	// Check local actors first
	if actor_id in c.local_actors {
		return c.node_id
	}

	// Check remote actors
	for node_id, node in c.nodes {
		if actor_id in node.actors {
			return node_id
		}
	}

	return none
}

// send_message sends message to an actor (possibly remote)
pub fn (mut c Cluster) send_message(actor_id string, msg Message) ! {
	target_node := c.find_actor_node(actor_id)

	if target_node == none {
		return error('actor not found: ${actor_id}')
	}

	if node_id := target_node {
		if node_id == c.node_id {
			c.handle_local_message(actor_id, msg)
		} else {
			c.send_remote_message(node_id, actor_id, msg)!
		}
	}
}

// handle_local_message handles message for local actor
fn (mut c Cluster) handle_local_message(actor_id string, msg Message) {
	println('Local message to ${actor_id}: ${msg.payload}')
}

// send_remote_message sends message to remote actor
fn (mut c Cluster) send_remote_message(node_id string, actor_id string, msg Message) ! {
	if node_id !in c.nodes {
		return error('node not found: ${node_id}')
	}

	node := c.nodes[node_id]
	println('Remote message to ${actor_id} on ${node.address}:${node.port}')
}

// listen_for_peers listens for peer connections
fn (mut c Cluster) listen_for_peers() {
	for c.is_running {
		// Accept peer connections
		// Handle join requests
		// Handle actor migration requests
		time.sleep(100 * time.millisecond)
	}
}

// send_heartbeats sends periodic heartbeats
fn (mut c Cluster) send_heartbeats() {
	for c.is_running {
		now := time.now().unix_milli()

		for _, mut node in c.nodes {
			// Check if node is alive (10 second timeout)
			if now - node.last_heartbeat > 10000 {
				c.handle_node_failure(node.id)
			}
		}

		// Send heartbeat to all nodes
		for _, node in c.nodes {
			println('Sending heartbeat to ${node.id}')
		}

		time.sleep(2 * time.second) // 2 second interval
	}
}

// handle_node_failure handles node failure
fn (mut c Cluster) handle_node_failure(node_id string) {
	println('Node ${node_id} appears to be down, initiating failover')

	if node_id !in c.nodes {
		return
	}

	mut node := c.nodes[node_id]
	node.state = .offline
}

// sync_actor_locations synchronizes actor locations with cluster
fn (mut c Cluster) sync_actor_locations() ! {
	// Request actor location table from all nodes
	// Merge into local view
}

// get_stats returns cluster statistics
pub fn (c &Cluster) get_stats() ClusterStats {
	mut total_actors := c.local_actors.len
	for _, node in c.nodes {
		total_actors += node.actors.len
	}

	mut leader_id := ''
	for _, node in c.nodes {
		if node.state == .leader {
			leader_id = node.id
			break
		}
	}

	return ClusterStats{
		node_count:   c.nodes.len + 1
		local_actors: c.local_actors.len
		total_actors: total_actors
		leader_id:    leader_id
	}
}

// get_node_count returns the number of nodes in cluster
pub fn (c &Cluster) get_node_count() int {
	return c.nodes.len + 1 // +1 for local node
}

// add_node adds a node to the cluster
pub fn (mut c Cluster) add_node(node Node) {
	c.nodes[node.id] = node
}

// remove_node removes a node from the cluster
pub fn (mut c Cluster) remove_node(node_id string) {
	c.nodes.delete(node_id)
}

// get_node retrieves a node by ID
pub fn (c &Cluster) get_node(node_id string) ?Node {
	return c.nodes[node_id] or { return none }
}
