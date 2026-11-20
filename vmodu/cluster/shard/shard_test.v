// shard_test.v - Unit tests for cluster shard module

module shard

fn test_new_consistent_hasher() {
	hasher := new_consistent_hasher()

	assert hasher.node_count == 0
	assert hasher.replicas == 150
	assert hasher.nodes.len == 0
}

fn test_add_remove_node() {
	mut hasher := new_consistent_hasher()

	hasher.add_node('node-1')
	assert hasher.node_count == 1
	assert hasher.nodes.len == 150 // 150 virtual nodes

	hasher.add_node('node-2')
	assert hasher.node_count == 2
	assert hasher.nodes.len == 300

	hasher.remove_node('node-1')
	assert hasher.node_count == 1
	assert hasher.nodes.len == 150
}

fn test_get_node() {
	mut hasher := new_consistent_hasher()

	// Should return empty when no nodes
	node := hasher.get_node('actor-1')
	assert node == ''

	// Add nodes
	hasher.add_node('node-1')
	hasher.add_node('node-2')
	hasher.add_node('node-3')

	// Get node for key
	node1 := hasher.get_node('actor-1')
	assert node1 != ''

	// Same key should return same node (consistency)
	node1_again := hasher.get_node('actor-1')
	assert node1 == node1_again

	// Different keys may return different nodes
	node2 := hasher.get_node('actor-2')
	// Note: Due to hashing, different keys may map to same node
}

fn test_get_backup_node() {
	mut hasher := new_consistent_hasher()

	// Should return empty when only one node
	hasher.add_node('node-1')
	backup := hasher.get_backup_node('actor-1', 'node-1')
	assert backup == ''

	// Add more nodes
	hasher.add_node('node-2')
	hasher.add_node('node-3')

	// Get backup node
	backup1 := hasher.get_backup_node('actor-1', 'node-1')
	assert backup1 != ''
	assert backup1 != 'node-1'
}

fn test_get_nodes() {
	mut hasher := new_consistent_hasher()

	nodes := hasher.get_nodes()
	assert nodes.len == 0

	hasher.add_node('node-1')
	hasher.add_node('node-2')

	nodes2 := hasher.get_nodes()
	assert nodes2.len == 2
	assert 'node-1' in nodes2
	assert 'node-2' in nodes2
}

fn test_get_stats() {
	mut hasher := new_consistent_hasher()

	stats := hasher.get_stats()
	assert stats.physical_nodes == 0
	assert stats.virtual_nodes == 0
	assert stats.replicas == 150

	hasher.add_node('node-1')

	stats2 := hasher.get_stats()
	assert stats2.physical_nodes == 1
	assert stats2.virtual_nodes == 150
	assert stats2.avg_vnode_count == 150
}

fn test_new_shard_manager() {
	mut sm := new_shard_manager(3) // replication factor of 3

	assert sm.replication_factor == 3
	assert sm.get_node_count() == 0
}

fn test_shard_manager_add_remove() {
	mut sm := new_shard_manager(2)

	sm.add_node('node-1')
	sm.add_node('node-2')
	assert sm.get_node_count() == 2

	sm.remove_node('node-1') or {
		assert false, 'remove failed: ${err}'
	}
	assert sm.get_node_count() == 1
}

fn test_get_actor_location() {
	mut sm := new_shard_manager(3)

	sm.add_node('node-1')
	sm.add_node('node-2')
	sm.add_node('node-3')

	location := sm.get_actor_location('actor-1')

	assert location.primary != ''
	assert location.replicas.len <= 2 // replication_factor - 1

	// Check primary is not in replicas
	for replica in location.replicas {
		assert replica != location.primary
	}
}

fn test_actor_location_is_local() {
	location := ActorLocation{
		primary:  'node-1'
		replicas: ['node-2', 'node-3']
	}

	assert location.is_local('node-1') == true
	assert location.is_local('node-2') == false
	assert location.is_local('node-4') == false
}

fn test_actor_location_get_all_nodes() {
	location := ActorLocation{
		primary:  'node-1'
		replicas: ['node-2', 'node-3']
	}

	nodes := location.get_all_nodes()
	assert nodes.len == 3
	assert 'node-1' in nodes
	assert 'node-2' in nodes
	assert 'node-3' in nodes
}
