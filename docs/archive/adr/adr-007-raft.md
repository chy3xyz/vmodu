# ADR-007: Raft for Distributed Consensus

## Status
Accepted

## Context
For v2.2.0 distributed cluster feature, we needed a consensus algorithm to:
- Elect a leader among nodes
- Replicate actor location metadata
- Ensure consistency across cluster
- Handle node failures gracefully

## Decision
We chose **Raft** consensus algorithm.

## Consequences

### Positive
- **Understandability**: Easier to understand than Paxos
- **Strong Consistency**: Linearizable reads/writes
- **Fault Tolerance**: Tolerates minority of node failures
- **Leader-Based**: Simple client interaction
- **Proven**: Used by etcd, Consul, TiKV

### Negative
- **Write Latency**: Requires majority replication
- **Leader Bottleneck**: All writes go through leader
- **Split Brain Risk**: Without proper configuration
- **Complexity**: More complex than single-node

## Alternatives Considered

### Paxos
**Why not chosen:**
- Harder to implement correctly
- Poorly understood by many developers
- More complex leader election

### Gossip Protocol
**Why not chosen:**
- Eventual consistency not suitable for actor locations
- Harder to reason about state

### Single Leader (No Consensus)
**Why not chosen:**
- Single point of failure
- No automatic failover

## Implementation

- Leader election via randomized timeouts
- Log replication for actor location changes
- Heartbeats for failure detection
- Snapshotting for log compaction

## References
- [Raft Paper](https://raft.github.io/raft.pdf)
- [Raft Visualization](http://thesecretlivesofdata.com/raft/)
- [etcd Raft](https://github.com/etcd-io/raft)
