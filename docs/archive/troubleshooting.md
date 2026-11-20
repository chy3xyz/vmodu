# Troubleshooting Guide

Common issues and solutions for VModulith Runtime.

## Quick Diagnostics

```bash
# Check system health
vmodu doctor

# Check logs
journalctl -u vmodu -f

# Check metrics
curl http://localhost:8080/metrics

# Test connectivity
vmodu ping
```

## Installation Issues

### "v: command not found"

**Symptoms**: Cannot run `v` command after installation.

**Solutions**:

```bash
# Option 1: Add to PATH
export PATH=$PATH:/usr/local/v

# Option 2: Create symlink
sudo ln -s /path/to/v /usr/local/bin/v

# Option 3: Reinstall V
sudo ./v symlink
```

### "undefined: C.wasm_engine_new"

**Symptoms**: Compilation error about wasmtime C bindings.

**Solutions**:

```bash
# macOS
brew install wasmtime

# Ubuntu/Debian
wget https://github.com/bytecodealliance/wasmtime/releases/download/v15.0.0/wasmtime-dev-ubuntu-22.04-x86_64.tar.gz
tar -xzf wasmtime-dev-*.tar.gz
sudo cp -r include/wasmtime /usr/local/include/
sudo cp lib/* /usr/local/lib/

# Set flags
export CFLAGS="-I/usr/local/include"
export LDFLAGS="-L/usr/local/lib -lwasmtime"
```

### Build Failures

**Symptoms**: `v build` fails with errors.

**Solutions**:

```bash
# Clean build
make clean
make build

# Update V
v up

# Check V version
v version  # Should be 0.5.0+

# Verbose build
v -g cmd/vmodud/main.v
```

## Runtime Issues

### High Memory Usage

**Symptoms**: Memory grows continuously, OOM kills.

**Diagnostics**:

```bash
# Check memory usage
ps aux | grep vmodu
free -h

# Check actor count
curl http://localhost:8080/api/actors/count

# Profile memory
vmodu --profile-mem
```

**Solutions**:

```json
// config.json - Reduce limits
{
  "runtime": {
    "max_actors": 100000,
    "mailbox_size": 50
  },
  "wasm": {
    "memory_limit": 8388608  // 8MB
  }
}
```

### Slow Message Processing

**Symptoms**: High latency, message backlog.

**Diagnostics**:

```bash
# Check scheduler stats
curl http://localhost:8080/api/scheduler/stats

# Check queue depths
vmodu inspect queues

# Profile CPU
vmodu --profile-cpu
```

**Solutions**:

```json
// Increase workers
{
  "runtime": {
    "scheduler_workers": 32
  }
}
```

```bash
# Restart with more resources
vmodu --workers 32 --max-actors 500000
```

### Port Already in Use

**Symptoms**: `bind: address already in use`

**Solutions**:

```bash
# Find process
sudo lsof -i :8080
sudo netstat -tlnp | grep 8080

# Kill process
sudo kill -9 <PID>

# Or change port
vmodu --http-port 8081
```

## Cluster Issues

### Node Cannot Join Cluster

**Symptoms**: Node stuck in "joining" state.

**Diagnostics**:

```bash
# Check network connectivity
ping <seed-node>
telnet <seed-node> 9000

# Check firewall
sudo iptables -L | grep 9000

# Check logs
journalctl -u vmodu | grep -i cluster
```

**Solutions**:

```bash
# Open firewall
sudo ufw allow 9000/tcp

# Check bind address
vmodu --bind-addr 0.0.0.0

# Restart with debug logging
vmodu --log-level debug
```

### Split Brain

**Symptoms**: Multiple nodes claim to be leader.

**Diagnostics**:

```bash
# Check Raft state on all nodes
curl http://node1:8080/api/cluster/raft/state
curl http://node2:8080/api/cluster/raft/state

# Check term numbers
curl http://localhost:8080/api/cluster/raft/term
```

**Solutions**:

1. Stop all nodes
2. Clear Raft data (backup first!)
3. Start nodes one by one, starting with seed node
4. Verify leader election

### Actor Migration Failure

**Symptoms**: Actors stuck during migration.

**Solutions**:

```bash
# Check migration status
curl http://localhost:8080/api/actors/migrations

# Cancel stuck migration
curl -X POST http://localhost:8080/api/actors/migrations/cancel

# Retry migration
vmodu cluster migrate --actor <id> --to <node>
```

## Event Store Issues

### Event Log Corruption

**Symptoms**: Cannot read events, checksum errors.

**Solutions**:

```bash
# Verify checksums
vmodu event-store verify

# Repair (may lose some events)
vmodu event-store repair --log swap_events

# Restore from backup
cp /backup/swap_events/* /data/vmodu/events/swap_events/
```

### Disk Full

**Symptoms**: Cannot append events, disk space errors.

**Solutions**:

```bash
# Check disk usage
df -h /data/vmodu

# Compact old segments
vmodu event-store compact --log swap_events

# Reduce retention
vmodu event-store set-retention --hours 72

# Archive old events
vmodu event-store archive --before "2024-01-01"
```

## WASM Issues

### Module Load Failure

**Symptoms**: `invalid wasm magic number` or similar errors.

**Solutions**:

```bash
# Verify WASM file
wasm-validate module.wasm

# Check file format
file module.wasm  # Should show "WebAssembly module"

# Recompile module
wasmtime compile module.wasm -o module.cwasm
```

### Execution Timeout

**Symptoms**: WASM calls timeout or exceed fuel limit.

**Solutions**:

```json
// Increase limits
{
  "wasm": {
    "cpu_time_ms": 10000,
    "fuel_limit": 50000000
  }
}
```

### Memory Limit Exceeded

**Symptoms**: WASM execution fails with memory errors.

**Solutions**:

```json
// Increase memory limit
{
  "wasm": {
    "memory_limit": 33554432  // 32MB
  }
}
```

Or optimize WASM module:

```rust
// Use wasm-opt to reduce size
wasm-opt -Oz module.wasm -o module_optimized.wasm
```

## Web3 Adapter Issues

### RPC Connection Failure

**Symptoms**: Cannot connect to blockchain nodes.

**Diagnostics**:

```bash
# Test RPC endpoint
curl -X POST https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check rate limits
vmodu adapters evm check-rpc
```

**Solutions**:

```bash
# Use backup RPC
vmodu config set adapters.evm.rpc_url "https://backup-rpc.com"

# Increase timeout
vmodu config set adapters.evm.timeout_ms 30000
```

### Transaction Failures

**Symptoms**: Transactions revert or fail to submit.

**Diagnostics**:

```bash
# Check gas price
curl -X POST <RPC> -d '{"method":"eth_gasPrice"}'

# Simulate transaction
vmodu adapters evm simulate <tx>
```

**Solutions**:

```json
// Increase gas limit
{
  "adapters": {
    "evm": {
      "gas_limit": 5000000
    }
  }
}
```

## Performance Issues

### High CPU Usage

**Diagnostics**:

```bash
# Profile CPU
vmodu --profile-cpu --duration 30

# Check goroutines
curl http://localhost:8080/debug/pprof/goroutine

# Find hot paths
vmodu --trace
```

**Solutions**:

- Reduce worker count if oversubscribed
- Check for infinite loops in custom code
- Enable CPU affinity to isolate VModulith

### High Latency

**Diagnostics**:

```bash
# Check p99 latency
curl http://localhost:8080/metrics | grep latency_p99

# Profile requests
vmodu --profile-requests
```

**Solutions**:

```bash
# Increase batch sizes
vmodu --event-batch-size 1000

# Tune scheduler
vmodu --scheduler-policy throughput
```

## Debugging

### Enable Debug Logging

```bash
# Set log level
export VMODU_LOG_LEVEL=debug
vmodu

# Or use flag
vmodu --log-level debug

# Enable specific modules
vmodu --log-modules "actor,cluster,event"
```

### Get Stack Trace

```bash
# On crash
gdb -p $(pidof vmodu)
bt full

# Or generate core dump
ulimit -c unlimited
vmodu
# After crash
gdb vmodu core
```

### Network Debugging

```bash
# Capture traffic
sudo tcpdump -i any -w vmodu.pcap port 8080 or port 9000

# Analyze with Wireshark
wireshark vmodu.pcap
```

## Getting Help

If issues persist:

1. **Check documentation**: [docs.vmodu.io](https://docs.vmodu.io)
2. **Search issues**: [GitHub Issues](https://github.com/vmodu/runtime/issues)
3. **Join Discord**: [discord.gg/vmodu](https://discord.gg/vmodu)
4. **Email support**: support@vmodu.io

### Report Bug

Include:
- VModulith version
- V version
- OS and version
- Configuration (redact secrets)
- Steps to reproduce
- Debug logs
- Core dump (if available)

```bash
# Gather diagnostics
vmodu doctor > diagnostics.txt
vmodu --version >> diagnostics.txt
v version >> diagnostics.txt
uname -a >> diagnostics.txt
```
