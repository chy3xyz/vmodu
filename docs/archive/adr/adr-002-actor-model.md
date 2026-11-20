# ADR-002: Actor Model for Concurrency

## Status
Accepted

## Context
We needed a concurrency model that would:
- Support millions of concurrent entities
- Avoid shared mutable state
- Provide fault isolation
- Enable location transparency for clustering
- Be simple to reason about

## Decision
We chose the **Actor Model** as the core concurrency paradigm.

## Consequences

### Positive
- **Isolation**: Each actor has private state, preventing data races
- **Scalability**: Millions of lightweight actors possible
- **Fault Tolerance**: Actor failures don't crash system
- **Distribution**: Natural fit for distributed systems
- **Composability**: Actors compose via message passing

### Negative
- **Learning Curve**: Different from thread-based programming
- **Debugging**: Message passing harder to trace than direct calls
- **Overhead**: Message copying vs shared memory
- **Deadlocks**: Possible with circular message patterns

## Alternatives Considered

### Threads + Mutexes
**Why not chosen:**
- Difficult to scale to millions of entities
- High risk of deadlocks and data races
- Expensive context switching

### Async/Await
**Why not chosen:**
- Callback complexity
- Harder to distribute across machines
- State management challenges

### Software Transactional Memory (STM)
**Why not chosen:**
- Complexity of transaction retries
- Limited language support in V
- Less intuitive than message passing

## Implementation Details

Each actor has:
- Unique ID
- Mailbox (channel with buffer)
- Message handler function
- Optional state

```v
struct Actor {
    id string
    mailbox chan Message
}
```

## References
- [Actor Model](https://en.wikipedia.org/wiki/Actor_model)
- [Erlang/OTP](https://www.erlang.org/)
- [Akka Actors](https://akka.io/)
