// node_test.v - Unit tests for cluster node module

module node

fn test_new_node() {
	node := new_node('node-1', '127.0.0.1', 8080)

	assert node.id == 'node-1'
	assert node.address == '127.0.0.1'
	assert node.port == 8080
	assert node.raft_port == 9080
	assert node.state == .follower
	assert node.health_score == 100
}

fn test_node_state() {
	mut node := new_node('node-1', '127.0.0.1', 8080)

	assert node.is_leader() == false

	node.set_state(.leader)
	assert node.state == .leader
	assert node.is_leader() == true

	node.set_state(.offline)
	assert node.state == .offline
}

fn test_node_actors() {
	mut node := new_node('node-1', '127.0.0.1', 8080)

	actor := RemoteActor{
		id:       'actor-1'
		actor_id: 'actor-1'
		node_id:  'node-1'
	}

	node.add_actor(actor)
	assert node.actors.len == 1

	retrieved := node.get_actor('actor-1')
	assert retrieved != none

	node.remove_actor('actor-1')
	assert node.actors.len == 0
}

fn test_new_cluster() {
	cluster := new_cluster('local', '0.0.0.0', 9000)

	assert cluster.node_id == 'local'
	assert cluster.bind_addr == '0.0.0.0'
	assert cluster.bind_port == 9000
	assert cluster.is_running == false
}

fn test_cluster_local_actors() {
	mut cluster := new_cluster('local', '0.0.0.0', 9000)

	cluster.add_local_actor('actor-1')
	assert cluster.local_actors.len == 1

	found_node := cluster.find_actor_node('actor-1')
	assert found_node != none
	if node_id := found_node {
		assert node_id == 'local'
	}

	cluster.remove_local_actor('actor-1')
	assert cluster.local_actors.len == 0
}

fn test_cluster_nodes() {
	mut cluster := new_cluster('local', '0.0.0.0', 9000)

	node := new_node('remote-1', '192.168.1.1', 8080)
	cluster.add_node(node)

	assert cluster.get_node_count() == 2

	retrieved := cluster.get_node('remote-1')
	assert retrieved != none

	cluster.remove_node('remote-1')
	assert cluster.get_node_count() == 1
}

fn test_cluster_stats() {
	mut cluster := new_cluster('local', '0.0.0.0', 9000)

	// Add local actor
	cluster.add_local_actor('local-actor')

	// Add remote node with actors
	mut node := new_node('remote-1', '192.168.1.1', 8080)
	node.set_state(.leader)
	node.add_actor(RemoteActor{
		id:       'remote-actor'
		actor_id: 'remote-actor'
		node_id:  'remote-1'
	})
	cluster.add_node(node)

	stats := cluster.get_stats()

	assert stats.node_count == 2
	assert stats.local_actors == 1
	assert stats.total_actors == 2
	assert stats.leader_id == 'remote-1'
}

fn test_find_actor_node() {
	mut cluster := new_cluster('local', '0.0.0.0', 9000)

	// Add local actor
	cluster.add_local_actor('local-actor')

	// Add remote node with actor
	mut node := new_node('remote-1', '192.168.1.1', 8080)
	node.add_actor(RemoteActor{
		id:       'remote-actor'
		actor_id: 'remote-actor'
		node_id:  'remote-1'
	})
	cluster.add_node(node)

	// Find local actor
	local_node := cluster.find_actor_node('local-actor')
	assert local_node != none
	if node_id := local_node {
		assert node_id == 'local'
	}

	// Find remote actor
	remote_node := cluster.find_actor_node('remote-actor')
	assert remote_node != none
	if node_id := remote_node {
		assert node_id == 'remote-1'
	}

	// Find non-existent actor
	not_found := cluster.find_actor_node('non-existent')
	assert not_found == none
}
