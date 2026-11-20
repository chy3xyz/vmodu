# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records (ADRs) for VModulith Runtime.

## What is an ADR?

An ADR captures an important architectural decision made along with its context and consequences. It helps:
- Document why decisions were made
- Onboard new team members
- Revisit decisions when context changes
- Maintain institutional knowledge

## Format

Each ADR follows this format:

```markdown
# ADR-XXX: Title

## Status
- Proposed / Accepted / Deprecated / Superseded by ADR-YYY

## Context
What is the issue we're solving? What forces are at play?

## Decision
What we decided to do.

## Consequences
What becomes easier/harder because of this decision?

## Alternatives Considered
What else did we consider and why didn't we choose it?
```

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [001](adr-001-language-choice.md) | Choice of V Programming Language | Accepted | 2024-01 |
| [002](adr-002-actor-model.md) | Actor Model for Concurrency | Accepted | 2024-01 |
| [003](adr-003-event-driven.md) | Event-Driven Architecture | Accepted | 2024-01 |
| [004](adr-004-modulith.md) | Modular Monolith (Modulith) | Accepted | 2024-01 |
| [005](adr-005-wasm.md) | WASM for Tool Sandbox | Accepted | 2024-02 |
| [006](adr-006-intent-protocol.md) | Intent Protocol | Accepted | 2024-02 |
| [007](adr-007-raft.md) | Raft for Distributed Consensus | Accepted | 2024-03 |
| [008](adr-008-graphql.md) | GraphQL for API | Accepted | 2024-03 |

## Creating New ADRs

1. Use the next available number
2. Copy the template below
3. Submit as PR for review
4. Mark as "Proposed" initially
5. Update to "Accepted" after merge

## Template

```markdown
# ADR-XXX: Title

## Status
Proposed

## Context

## Decision

## Consequences

### Positive
- 

### Negative
- 

## Alternatives Considered

### Alternative 1
**Why not chosen:**

### Alternative 2
**Why not chosen:**

## References
- 
```
