# Technical Debt & Improvement Plan

## Technical Debt Register

### Critical 🔴

#### TD-001: Event Store File I/O Performance
**Location**: `infra/db/event_store.v:187-191`
**Debt**: Opening/closing file for every event append
**Impact**: Severe performance degradation under load (>1000 events/sec)
**Effort**: 2 days
**Fix**: Implement buffered writer with periodic flush

```v
// Current (SLOW):
mut file := os.open_append(segment.file_path)!
file.writeln(json_data)!
file.close()

// Target (FAST):
segment.buffer << data
if should_flush(segment) {
    segment.file.write(segment.buffer)!
    segment.buffer.clear()
}
```

---

#### TD-002: EventBus Race Conditions
**Location**: `event/bus/bus.v:38-42`
**Debt**: Unsynchronized access to subscribers map
**Impact**: Data races, potential crashes under concurrent load
**Effort**: 1 day
**Fix**: Add read-write mutex

---

#### TD-003: Raft RPC Not Implemented
**Location**: `cluster/raft/raft.v:128-141`
**Debt**: All network operations are simulated
**Impact**: Cluster functionality is non-functional
**Effort**: 5 days
**Fix**: Implement TCP/HTTP RPC layer

---

### High 🟠

#### TD-004: Actor Goroutine Leaks
**Location**: `runtime/actor/actor.v:35-41`
**Debt**: No graceful shutdown mechanism for actor goroutines
**Impact**: Resource leaks during actor lifecycle
**Effort**: 2 days

#### TD-005: LLM Client Stub Implementation
**Location**: `agent/llm/client.v:77-102`
**Debt**: Returns mock data instead of actual API calls
**Impact**: AI features non-functional
**Effort**: 2 days

#### TD-006: WASM Runtime Placeholder
**Location**: `wasm/wasmtime/runtime.v`
**Debt**: No actual wasmtime integration
**Impact**: Tool sandboxing is simulated only
**Effort**: 5 days

---

### Medium 🟡

#### TD-007: Missing Metrics Collection
**Location**: Global
**Debt**: No Prometheus/OpenTelemetry integration
**Impact**: Cannot monitor production health
**Effort**: 3 days

#### TD-008: Inadequate Test Coverage
**Location**: cluster/, infra/db/, adapters/
**Debt**: <30% test coverage in critical modules
**Impact**: High regression risk
**Effort**: 2 weeks

#### TD-009: No Circuit Breaker Pattern
**Location**: adapters/, infra/
**Debt**: External calls can cascade failures
**Impact**: System instability during outages
**Effort**: 3 days

#### TD-010: Missing Request Timeouts
**Location**: Multiple modules
**Debt**: Many operations can block indefinitely
**Impact**: System hangs
**Effort**: 2 days

---

### Low 🟢

#### TD-011: String-based Event Data
**Location**: `event/bus/bus.v:7`
**Debt**: `map[string]string` limits data types
**Impact**: Requires serialization overhead
**Effort**: 1 day

#### TD-012: Magic Numbers
**Location**: Multiple
**Debt**: Hard-coded constants throughout
**Impact**: Maintenance difficulty
**Effort**: 1 day

#### TD-013: Println Debugging
**Location**: Multiple
**Debt**: Using println instead of structured logging
**Impact**: Hard to filter/debug in production
**Effort**: 2 days

---

## Improvement Roadmap

### Week 1-2: Stability Foundation

```
Priority: Critical + High
Focus: Fix blocking issues for MVP

Tasks:
☐ TD-001: Event Store buffering
☐ TD-002: EventBus synchronization  
☐ TD-010: Add request timeouts
☐ Add structured logging (slog/log)
☐ Basic health check endpoint
```

### Week 3-4: Core Functionality

```
Priority: High
Focus: Make core features work

Tasks:
☐ TD-005: Implement LLM HTTP client
☐ TD-006: WASM runtime integration
☐ TD-004: Actor lifecycle management
☐ Implement missing RPC for Raft
☐ Add connection pooling
```

### Week 5-6: Production Hardening

```
Priority: Medium
Focus: Production readiness

Tasks:
☐ TD-007: Metrics collection
☐ TD-009: Circuit breakers
☐ TD-003: Raft network layer
☐ Add request tracing
☐ Implement proper error propagation
```

### Week 7-8: Quality & Testing

```
Priority: Medium + Low
Focus: Reliability and maintainability

Tasks:
☐ TD-008: Increase test coverage to 70%
☐ TD-011: Type-safe event data
☐ TD-012: Extract constants
☐ TD-013: Replace println with logging
☐ Add integration tests
☐ Load testing suite
```

---

## Code Smells Inventory

### Smell 1: Feature Envy
**Example**: `PersistentLog` manipulates `LogSegment` internals extensively
**Fix**: Move methods to appropriate types

### Smell 2: Shotgun Surgery
**Example**: Adding new event type requires changes in 5+ files
**Fix**: Centralize event type definitions

### Smell 3: Data Clumps
**Example**: `(address string, port int)` repeated throughout
**Fix**: Create `Address` struct

### Smell 4: Primitive Obsession
**Example**: Using `string` for IDs, timestamps
**Fix**: Create `ActorID`, `Timestamp` types

### Smell 5: Temporary Field
**Example**: `votes_received` only used during election
**Fix**: Encapsulate election state

---

## Refactoring Priorities

### High Impact, Low Effort

1. **Extract Constants**
   ```v
   // Before
   time.sleep(100 * time.millisecond)
   
   // After
   const heartbeat_interval = 100 * time.millisecond
   ```

2. **Add Missing Error Context**
   ```v
   // Before
   return error('failed')
   
   // After
   return error('failed to load module ${name}: ${err}')
   ```

3. **Replace Magic Numbers**
   ```v
   const (
       default_mailbox_size = 100
       max_mailbox_size     = 10000
   )
   ```

### High Impact, High Effort

1. **Implement Proper RPC Layer**
   ```v
   pub interface RPCClient {
       call(method string, req []u8, timeout time.Duration) ![]u8
   }
   ```

2. **Add Event Sourcing Support**
   ```v
   pub interface EventSourced {
       apply_event(e Event)
       to_snapshot() []u8
       from_snapshot(data []u8) !
   }
   ```

---

## Architecture Improvements

### Current Issues

```
┌─────────────────┐
│   Direct calls  │  ← Tight coupling
│   everywhere    │
└─────────────────┘
```

### Target Architecture

```
┌─────────────────┐
│   Event Bus     │  ← Loose coupling
│   (mediator)    │
└─────────────────┘
       ↑↓
┌──────┴──────────┐
│   Interfaces    │  ← Dependency inversion
└─────────────────┘
```

### Recommended Patterns

1. **CQRS for Event Store**
   ```v
   // Separate read/write paths
   pub interface EventWriter {
       append(e Event) !u64
   }
   
   pub interface EventReader {
       read(from u64, count int) []Event
       subscribe(filter EventFilter) chan Event
   }
   ```

2. **Circuit Breaker for Adapters**
   ```v
   pub struct CircuitBreaker {
       state      State
       failures   int
       threshold  int
       timeout    time.Duration
   }
   
   pub fn (cb CircuitBreaker) call(fn () !) ! {
       if cb.state == .open {
           return error('circuit open')
       }
       // ...
   }
   ```

3. **Connection Pool**
   ```v
   pub struct Pool<T> {
       items      chan T
       factory    fn () !T
       max_size   int
   }
   ```

---

## Performance Targets

### Current Baseline

| Metric | Current | Target |
|--------|---------|--------|
| Event append | 100/s | 10,000/s |
| Message routing | 1,000/s | 100,000/s |
| Actor creation | 100/s | 10,000/s |
| Memory/actor | ~100B | ~64B |

### Optimization Strategies

1. **Zero-Copy Messaging**
   ```v
   // Use reference counting instead of cloning
   pub struct Message {
       data &Data  // shared reference
       refs int   // reference count
   }
   ```

2. **Memory Pooling**
   ```v
   // Pre-allocate and reuse
   pub struct ActorPool {
       available chan &Actor
       in_use    map[string]&Actor
   }
   ```

3. **Lock-Free Data Structures**
   ```v
   // Use V's lock-free channels effectively
   // Consider lock-free queues for high contention
   ```

---

## Definition of Done

### For Each Fix

- [ ] Code implemented
- [ ] Unit tests added (coverage >80%)
- [ ] Integration tests added
- [ ] Documentation updated
- [ ] Benchmark comparison (before/after)
- [ ] Reviewed by peer
- [ ] No new warnings/clippy errors

### For Each Module

- [ ] Public API documented
- [ ] Examples provided
- [ ] Error handling complete
- [ ] Metrics exposed
- [ ] Health checks implemented

---

## Success Metrics

### After Completion

| Metric | Before | After |
|--------|--------|-------|
| Test Coverage | 35% | 80% |
| Critical Issues | 12 | 0 |
| Performance | Baseline | 10x |
| Docs Coverage | 60% | 95% |
| Build Warnings | 45 | 0 |

---

**Total Estimated Effort**: 8 weeks (2 senior engineers)
**Risk Level**: Medium (requires careful testing)
**Expected Outcome**: Production-ready v1.0
