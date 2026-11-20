# Performance Tuning Guide

Optimize VModulith Runtime for maximum throughput and minimal latency.

## Performance Targets

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Actors | 1,000,000+ | `vmodu metrics actors` |
| Msg/sec | 1,000,000+ | `vmodu benchmark msg` |
| Latency (p99) | < 1ms | `vmodu benchmark latency` |
| Throughput | 1M+ QPS | Load testing |

## System Tuning

### Kernel Parameters

Edit `/etc/sysctl.d/99-vmodu.conf`:

```bash
# Network
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_slow_start_after_idle = 0

# Memory
vm.swappiness = 1
vm.dirty_ratio = 40
vm.dirty_background_ratio = 10
vm.max_map_count = 262144

# File system
fs.nr_open = 2097152
fs.file-max = 2097152
```

Apply:

```bash
sudo sysctl --system
```

### File Descriptors

```bash
# Check current limit
ulimit -n

# Increase limit
ulimit -n 65536

# Or in /etc/security/limits.conf
vmodu soft nofile 65536
vmodu hard nofile 65536
```

### CPU Governor

```bash
# Set performance governor (Linux)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Or use cpupower
sudo cpupower frequency-set -g performance
```

### NUMA Optimization

```bash
# Check NUMA topology
numactl --hardware

# Run on specific NUMA node
numactl --cpunodebind=0 --membind=0 vmodu

# Or interleave across nodes
numactl --interleave=all vmodu
```

## VModulith Configuration

### Scheduler Tuning

```json
{
  "runtime": {
    "scheduler_workers": 32,
    "worker_queue_size": 100000,
    "mailbox_size": 100,
    "actor_idle_timeout_ms": 60000,
    "worker_stealing": true,
    "work_stealing_attempts": 5
  }
}
```

**Guidelines:**
- `scheduler_workers`: Number of CPUs or slightly less
- `worker_queue_size`: 10x expected peak throughput
- `mailbox_size`: Balance memory vs backpressure

### Memory Tuning

```json
{
  "runtime": {
    "gc_target_percent": 100,
    "memory_limit_mb": 8192
  },
  "event": {
    "store_buffer_size": 10000
  }
}
```

### Network Tuning

```json
{
  "gateway": {
    "tcp_keepalive": true,
    "tcp_nodelay": true,
    "tcp_fastopen": true,
    "read_buffer_size": 65536,
    "write_buffer_size": 65536,
    "max_connections": 100000
  }
}
```

## Benchmarking

### Message Throughput

```bash
# Run benchmark
vmodu benchmark msg --actors 10000 --duration 60s --rate 1000000

# Expected output:
# Total messages: 60,000,000
# Throughput: 1,000,000 msg/s
# Latency p50: 0.5ms
# Latency p99: 1.2ms
```

### Actor Scaling

```bash
# Test actor creation
vmodu benchmark actors --count 1000000 --parallel 100

# Monitor memory
top -p $(pidof vmodu)
```

### Event Store Performance

```bash
# Write throughput
vmodu benchmark events --writes 1000000 --parallel 50

# Read throughput
vmodu benchmark events --reads 1000000 --batch-size 1000
```

### Cluster Performance

```bash
# Cross-node messaging
vmodu benchmark cluster --nodes 3 --messages 10000000

# Measure latency
vmodu benchmark latency --target node-2
```

## Profiling

### CPU Profiling

```bash
# Enable CPU profiling
vmodu --profile-cpu --profile-file cpu.pprof

# Analyze
go tool pprof cpu.pprof
(pprof) top
(pprof) web
```

### Memory Profiling

```bash
# Enable memory profiling
vmodu --profile-mem --profile-file mem.pprof

# Analyze
go tool pprof mem.pprof
(pprof) top
(pprof) list <function>
```

### Tracing

```bash
# Enable execution trace
vmodu --trace --trace-file trace.out

# Analyze
go tool trace trace.out
```

## Common Bottlenecks

### High Memory Usage

**Symptoms**: Frequent GC, OOM errors

**Solutions**:

```json
// Reduce mailbox sizes
{
  "runtime": {
    "mailbox_size": 50,
    "gc_target_percent": 200
  }
}
```

```bash
# Limit actors
vmodu --max-actors 500000

# Enable memory profiling
vmodu --profile-mem
```

### High Latency

**Symptoms**: Slow message processing

**Solutions**:

```bash
# Increase workers
vmodu --workers 64

# Check for blocking operations
vmodu --trace-blocking

# Optimize event handlers
```

### Event Store Lag

**Symptoms**: Events accumulating

**Solutions**:

```json
// Increase flush interval
{
  "event": {
    "flush_interval_ms": 10,
    "batch_size": 1000
  }
}
```

```bash
# Use faster storage
# SSD recommended for event store
```

## Cluster Optimization

### Consistent Hashing

```json
{
  "cluster": {
    "virtual_nodes": 300,
    "replication_factor": 3
  }
}
```

**Guidelines:**
- More virtual nodes = better distribution
- Higher replication = better availability

### Network Topology

```
Recommended: Full mesh
Latency between nodes: < 5ms
Bandwidth: 10 Gbps+
```

### Raft Tuning

```json
{
  "cluster": {
    "raft": {
      "heartbeat_interval_ms": 100,
      "election_timeout_min_ms": 150,
      "election_timeout_max_ms": 300,
      "snapshot_interval": 10000
    }
  }
}
```

## Web3 Optimization

### Connection Pooling

```json
{
  "adapters": {
    "evm": {
      "pool_size": 50,
      "max_idle": 20,
      "idle_timeout_ms": 30000,
      "connection_timeout_ms": 5000
    }
  }
}
```

### Batch Requests

```bash
# Enable batching
vmodu config set adapters.evm.batch_requests true

# Set batch size
vmodu config set adapters.evm.batch_size 100
```

## Monitoring Performance

### Key Metrics

```bash
# Actor metrics
curl http://localhost:9091/metrics | grep vmodu_actor

# Message throughput
curl http://localhost:9091/metrics | grep vmodu_messages_per_second

# Latency
curl http://localhost:9091/metrics | grep vmodu_latency

# Event store
curl http://localhost:9091/metrics | grep vmodu_event_store
```

### Prometheus Queries

```promql
# Actor count
vmodu_actor_count

# Message rate
rate(vmodu_messages_total[1m])

# P99 latency
histogram_quantile(0.99, rate(vmodu_latency_bucket[5m]))

# Cluster health
vmodu_cluster_health
```

### Grafana Dashboard

Import dashboard ID: `vmodu-performance`

Key panels:
- Actor count over time
- Message throughput
- Latency percentiles
- Resource utilization
- Cluster health

## Load Testing

### Using k6

```javascript
// loadtest.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 1000 },
    { duration: '5m', target: 10000 },
    { duration: '1m', target: 0 },
  ],
};

export default function () {
  const res = http.post('http://localhost:8080/api/intent', {
    action: 'test',
    params: {}
  });
  
  check(res, {
    'status is 200': (r) => r.status === 200,
    'latency < 100ms': (r) => r.timings.duration < 100,
  });
}
```

Run:

```bash
k6 run loadtest.js
```

### Using wrk

```bash
# HTTP benchmark
wrk -t12 -c400 -d30s http://localhost:8080/health

# With Lua script
wrk -t12 -c400 -d30s -s script.lua http://localhost:8080/api/intent
```

## Performance Checklist

Before production:

- [ ] Kernel parameters tuned
- [ ] File descriptor limits increased
- [ ] Scheduler workers configured
- [ ] Memory limits set
- [ ] Network buffers optimized
- [ ] Benchmark tests passing
- [ ] Latency targets met
- [ ] Throughput targets met
- [ ] Monitoring configured
- [ ] Alert thresholds set
- [ ] Load testing completed
- [ ] Failure scenarios tested

## References

- [Linux Performance Tuning](https://www.brendangregg.com/linuxperf.html)
- [Vlang Performance](https://vlang.io/performance)
- [High Performance Browser Networking](https://hpbn.co/)
