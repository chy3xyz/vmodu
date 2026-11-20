# VModulith Runtime Improvements Checklist

Use this checklist to track improvements. Items are prioritized by impact and effort.

## Legend
- 🔴 Critical - Fix immediately
- 🟠 High - Fix before production
- 🟡 Medium - Fix before v1.0
- 🟢 Low - Nice to have

---

## Phase 1: Critical Fixes (Week 1-2)

### Performance

- [ ] **🔴 Fix Event Store File I/O** (`infra/db/event_store.v`)
  - Current: Opens/closes file per event
  - Target: Buffered writes with flush interval
  - Effort: 2 days
  - Impact: 100x throughput improvement

```v
// Implementation hint:
pub struct BufferedWriter {
    file       os.File
    buffer     []u8
    capacity   int = 8192
    last_flush i64
}
```

- [ ] **🔴 Add EventBus Synchronization** (`event/bus/bus.v`)
  - Add `sync.RwMutex` to protect subscribers map
  - Effort: 1 day
  - Impact: Fixes race conditions

- [ ] **🟠 Implement Actor Graceful Shutdown** (`runtime/actor/actor.v`)
  - Add shutdown channel
  - Drain mailbox before exit
  - Effort: 1 day

### Reliability

- [ ] **🔴 Add Request Timeouts Everywhere**
  - All network calls need timeouts
  - All blocking operations need deadlines
  - Effort: 2 days

- [ ] **🟠 Replace println with Structured Logging**
  - Create logger module
  - Add log levels (debug/info/warn/error)
  - Add structured fields (JSON output)
  - Effort: 2 days

---

## Phase 2: Core Features (Week 3-4)

### Missing Implementations

- [ ] **🔴 Implement LLM HTTP Client** (`agent/llm/client.v`)
  - Use `net.http` module
  - Add retry logic with backoff
  - Add response caching
  - Effort: 2 days

```v
pub fn (c Client) complete(messages []Message) !CompletionResponse {
    req := http.new_request(.post, c.config.base_url + '/chat/completions', json_body)
    req.add_header(.authorization, 'Bearer ' + c.config.api_key)
    resp := req.do()!
    // Parse response
}
```

- [ ] **🔴 Integrate Real WASM Runtime** (`wasm/wasmtime/runtime.v`)
  - Add C bindings to wasmtime
  - Implement actual module loading
  - Add resource limit enforcement
  - Effort: 5 days

- [ ] **🟠 Implement Raft RPC Layer** (`cluster/raft/raft.v`)
  - Create TCP client/server
  - Implement AppendEntries RPC
  - Implement RequestVote RPC
  - Add serialization (json/msgpack)
  - Effort: 4 days

### Testing

- [ ] **🟠 Add Unit Tests for Event Store**
  - Test append/read
  - Test segment rotation
  - Test crash recovery
  - Target: 80% coverage
  - Effort: 2 days

- [ ] **🟠 Add Unit Tests for Actor Runtime**
  - Test message passing
  - Test lifecycle
  - Test error handling
  - Target: 80% coverage
  - Effort: 2 days

---

## Phase 3: Production Hardening (Week 5-6)

### Observability

- [ ] **🟡 Add Prometheus Metrics** (`infra/metrics/`)
  ```v
  pub fn record_message_processed(duration_ms f64) {
      metrics.counter('vmodu_messages_total').inc()
      metrics.histogram('vmodu_message_duration').observe(duration_ms)
  }
  ```
  - Counters: messages, events, actors
  - Gauges: active actors, queue depths
  - Histograms: latency
  - Effort: 3 days

- [ ] **🟡 Implement Health Check Endpoint** (`infra/health/`)
  ```v
  pub fn health_check() HealthStatus {
      return {
          status: check_actors() && check_event_bus() && check_store()
          checks: {
              'actors': check_actors(),
              'event_bus': check_event_bus(),
              // ...
          }
      }
  }
  ```
  - Effort: 2 days

- [ ] **🟡 Add Distributed Tracing**
  - Propagate trace IDs
  - Record spans for operations
  - Export to Jaeger/Zipkin
  - Effort: 3 days

### Resilience

- [ ] **🟡 Add Circuit Breaker Pattern** (`infra/circuit_breaker.v`)
  ```v
  pub struct CircuitBreaker {
      state      State  // closed, open, half-open
      failures   int
      threshold  int
      reset_timeout time.Duration
  }
  ```
  - Apply to all external calls (LLM, Web3)
  - Effort: 2 days

- [ ] **🟡 Add Retry Logic with Backoff** (`infra/retry.v`)
  ```v
  pub fn with_retry<T>(op fn () !T, config RetryConfig) !T {
      for attempt := 0; attempt < config.max_attempts; attempt++ {
          if result := op() {
              return result
          }
          time.sleep(exponential_backoff(attempt))
      }
      return error('max retries exceeded')
  }
  ```
  - Effort: 1 day

---

## Phase 4: Polish (Week 7-8)

### Code Quality

- [ ] **🟢 Extract Magic Numbers to Constants**
  - Search for hardcoded values
  - Move to `const` blocks
  - Add comments explaining values
  - Effort: 1 day

- [ ] **🟢 Add Missing Documentation**
  - All public functions need doc comments
  - All types need documentation
  - Add architecture diagrams
  - Effort: 2 days

- [ ] **🟢 Implement Missing Interfaces**
  - `Stringer` for debug output
  - `Equal` for testing
  - `Clone` for copying
  - Effort: 2 days

### Features

- [ ] **🟢 Add Configuration Hot Reload**
  - Watch config file for changes
  - Reload without restart
  - Validate before applying
  - Effort: 2 days

- [ ] **🟢 Add CLI Tool** (`cmd/vmoductl/`)
  ```bash
  vmoductl status          # Show cluster status
  vmoductl actors list     # List actors
  vmoductl events tail     # Tail event log
  vmoductl config reload   # Reload config
  ```
  - Effort: 3 days

- [ ] **🟢 Add Backup/Restore** (`infra/backup.v`)
  - Snapshot event store
  - Export/import actor state
  - Point-in-time recovery
  - Effort: 3 days

---

## Quick Wins (Do These First!)

### Can Do in 1 Day Each

1. **Add constants for magic numbers**
   ```v
   const (
       default_mailbox_size = 100
       default_segment_size = 1000
       heartbeat_interval   = 100 * time.millisecond
   )
   ```

2. **Fix error messages to include context**
   ```v
   // Before
   return error('failed')
   
   // After  
   return error('failed to append event to ${log_name}: ${err}')
   ```

3. **Add basic health check**
   ```v
   pub fn (r Runtime) health() bool {
       return r.actor_count > 0 && r.event_bus.running
   }
   ```

4. **Add simple metrics counter**
   ```v
   pub struct Metrics {
   pub mut:
       messages_processed u64
   }
   ```

5. **Validate inputs**
   ```v
   pub fn (mut r Router) route(i Intent) ! {
       if i.action == '' {
           return error('action cannot be empty')
       }
       // ...
   }
   ```

---

## Testing Checklist

### Before Each Release

- [ ] All unit tests pass: `v test .`
- [ ] No compiler warnings: `v -prod build`
- [ ] Benchmarks show improvement
- [ ] Memory leak check: `valgrind ./vmodu`
- [ ] Race condition check: `v -race test .`
- [ ] Load test: 1000+ actors, 10000+ messages

### Test Scenarios

- [ ] **Actor Lifecycle**
  - Create 1M actors
  - Send messages between them
  - Stop gracefully
  - Verify no goroutine leaks

- [ ] **Event Store Durability**
  - Append 1M events
  - Kill process midway
  - Restart and verify no corruption
  - Read events from start

- [ ] **Cluster Failover**
  - Start 3-node cluster
  - Kill leader
  - Verify new leader elected
  - Verify no data loss

- [ ] **WASM Isolation**
  - Run infinite loop in WASM
  - Verify CPU limit enforced
  - Verify memory limit enforced
  - Verify no crash

---

## Code Review Checklist

### For Each PR

- [ ] Code follows style guide
- [ ] All public functions documented
- [ ] Error handling complete (no unwrap/ignore)
- [ ] No `println` except in examples
- [ ] Tests added for new code
- [ ] Benchmarks added for performance-critical code
- [ ] No new compiler warnings
- [ ] Security review (input validation, etc.)

### Style Guide Reminders

- Use `snake_case` for functions
- Use `PascalCase` for types
- Use `SCREAMING_SNAKE_CASE` for constants
- Max function length: 50 lines
- Max file length: 500 lines
- Comment every public function

---

## Progress Tracking

```
Phase 1: Critical Fixes      [0/5]  0%
Phase 2: Core Features       [0/6]  0%
Phase 3: Prod Hardening      [0/7]  0%
Phase 4: Polish              [0/6]  0%
────────────────────────────────────
Overall                      [0/24] 0%
```

Update progress as items are completed!

---

## Getting Help

- **V Language**: https://vlang.io/docs
- **V Discord**: https://discord.gg/vlang
- **VModulith Issues**: https://github.com/vmodu/runtime/issues

Remember: Small improvements every day compound into big wins!
