// shard.v - Consistent Hashing for Actor Sharding
// Distributes actors across cluster nodes

module shard

import crypto.sha256

// VNode is a virtual node in the hash ring
pub struct VNode {
pub:
	hash    u32
	node_id string
}

// ConsistentHasher implements consistent hashing for distributing actors
pub struct ConsistentHasher {
pub mut:
	nodes      map[string]VNode // virtual nodes by hash key
	node_count int              // physical node count
	replicas   int              // virtual replicas per physical node
}

// new_consistent_hasher creates a new consistent hasher
pub fn new_consistent_hasher() ConsistentHasher {
	return ConsistentHasher{
		nodes:      {}
		node_count: 0
		replicas:   150 // 150 virtual nodes per physical node
	}
}

// add_node adds a physical node to the ring
pub fn (mut c ConsistentHasher) add_node(node_id string) {
	// Create virtual nodes for this physical node
	for i := 0; i < c.replicas; i++ {
		virtual_key := '${node_id}:${i}'
		hash := c.hash(virtual_key)

		c.nodes[hash.str()] = VNode{
			hash:    hash
			node_id: node_id
		}
	}

	c.node_count++
}

// remove_node removes a physical node from the ring
pub fn (mut c ConsistentHasher) remove_node(node_id string) {
	mut keys_to_remove := []string{}

	for key, vnode in c.nodes {
		if vnode.node_id == node_id {
			keys_to_remove << key
		}
	}

	for key in keys_to_remove {
		c.nodes.delete(key)
	}

	c.node_count--
}

// get_node returns the node for a key
pub fn (c &ConsistentHasher) get_node(key string) string {
	if c.node_count == 0 {
		return ''
	}

	hash := c.hash(key)

	// Find first virtual node with hash >= key hash
	mut target_node := ''
	mut min_hash := u32(0xFFFFFFFF)

	for _, vnode in c.nodes {
		if vnode.hash >= hash {
			if vnode.hash < min_hash {
				min_hash = vnode.hash
				target_node = vnode.node_id
			}
		}
	}

	// If no node found (wrap around), get the first node
	if target_node == '' {
		mut min_node_hash := u32(0xFFFFFFFF)
		for _, vnode in c.nodes {
			if vnode.hash < min_node_hash {
				min_node_hash = vnode.hash
				target_node = vnode.node_id
			}
		}
	}

	return target_node
}

// get_backup_node returns a backup node for replication
pub fn (c &ConsistentHasher) get_backup_node(key string, exclude_node string) string {
	if c.node_count <= 1 {
		return ''
	}

	hash := c.hash(key)

	// Find first two nodes excluding the specified node
	mut primary_hash := u32(0xFFFFFFFF)
	mut backup_hash := u32(0xFFFFFFFF)
	mut primary_node := ''
	mut backup_node := ''

	for _, vnode in c.nodes {
		if vnode.hash >= hash && vnode.node_id != exclude_node {
			if vnode.hash < primary_hash {
				backup_hash = primary_hash
				backup_node = primary_node
				primary_hash = vnode.hash
				primary_node = vnode.node_id
			} else if vnode.hash < backup_hash && vnode.node_id != primary_node {
				backup_hash = vnode.hash
				backup_node = vnode.node_id
			}
		}
	}

	// If not enough nodes found, wrap around
	if backup_node == '' {
		for _, vnode in c.nodes {
			if vnode.node_id != exclude_node && vnode.node_id != primary_node {
				backup_node = vnode.node_id
				break
			}
		}
	}

	return backup_node
}

// get_nodes returns all physical nodes
pub fn (c &ConsistentHasher) get_nodes() []string {
	mut node_set := map[string]bool{}

	for _, vnode in c.nodes {
		node_set[vnode.node_id] = true
	}

	mut nodes := []string{cap: node_set.len}
	for node, _ in node_set {
		nodes << node
	}
	nodes.sort()

	return nodes
}

// get_node_count returns number of physical nodes
pub fn (c &ConsistentHasher) get_node_count() int {
	return c.node_count
}

// hash calculates hash for a key
fn (c &ConsistentHasher) hash(key string) u32 {
	hash_str := sha256.hexhash(key)
	// Take first 8 hex chars as u32
	mut result := u32(0)
	for i := 0; i < 8 && i < hash_str.len; i++ {
		c_val := hash_str[i]
		mut digit := u32(0)

		if c_val >= `0` && c_val <= `9` {
			digit = u32(c_val - `0`)
		} else if c_val >= `a` && c_val <= `f` {
			digit = u32(c_val - `a` + 10)
		}

		result = (result << 4) | digit
	}
	return result
}

// RingStats contains statistics about the hash ring
pub struct RingStats {
pub:
	physical_nodes  int
	virtual_nodes   int
	replicas        int
	avg_vnode_count int
}

// get_stats returns statistics about the hash ring
pub fn (c &ConsistentHasher) get_stats() RingStats {
	return RingStats{
		physical_nodes:  c.node_count
		virtual_nodes:   c.nodes.len
		replicas:        c.replicas
		avg_vnode_count: if c.node_count > 0 { c.nodes.len / c.node_count } else { 0 }
	}
}

// ActorLocation contains location information for an actor
pub struct ActorLocation {
pub:
	primary  string
	replicas []string
}

// is_local checks if actor is local to given node
pub fn (a &ActorLocation) is_local(node_id string) bool {
	return a.primary == node_id
}

// get_all_nodes returns all nodes storing this actor
pub fn (a &ActorLocation) get_all_nodes() []string {
	mut nodes := [a.primary]
	nodes << a.replicas
	return nodes
}

// ShardManager manages actor sharding
pub struct ShardManager {
pub mut:
	hasher             ConsistentHasher
	replication_factor int
}

// new_shard_manager creates a new shard manager
pub fn new_shard_manager(replication int) ShardManager {
	return ShardManager{
		hasher:             new_consistent_hasher()
		replication_factor: replication
	}
}

// add_node adds a node to the shard manager
pub fn (mut s ShardManager) add_node(node_id string) {
	s.hasher.add_node(node_id)
}

// remove_node removes a node and triggers rebalancing
pub fn (mut s ShardManager) remove_node(node_id string) ! {
	s.hasher.remove_node(node_id)
	s.rebalance()!
}

// get_actor_location returns the primary and replica nodes for an actor
pub fn (s &ShardManager) get_actor_location(actor_id string) ActorLocation {
	primary := s.hasher.get_node(actor_id)

	mut replicas := []string{}
	mut exclude := primary

	for i := 0; i < s.replication_factor - 1; i++ {
		backup := s.hasher.get_backup_node(actor_id, exclude)
		if backup != '' && backup !in replicas && backup != primary {
			replicas << backup
			exclude = backup
		}
	}

	return ActorLocation{
		primary:  primary
		replicas: replicas
	}
}

// rebalance rebalances actors after topology change
fn (mut s ShardManager) rebalance() ! {
	// In production:
	// 1. Calculate which actors need to move
	// 2. Coordinate with cluster to migrate actors
	// 3. Update location mappings
}

// get_node_count returns the number of nodes
pub fn (s &ShardManager) get_node_count() int {
	return s.hasher.get_node_count()
}
