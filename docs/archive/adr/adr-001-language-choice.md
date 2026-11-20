# ADR-001: Choice of V Programming Language

## Status
Accepted

## Context
We needed to choose a programming language for VModulith Runtime that would support:
- High-performance concurrent execution (1M+ messages/sec)
- Small binary sizes (< 500KB ideal)
- Fast compilation for rapid development
- Memory safety without GC pauses
- C interoperability for wasmtime integration

## Decision
We chose the **V Programming Language** (Vlang).

## Consequences

### Positive
- **Performance**: Compiles to native code with C-like performance
- **Binary Size**: Single static binary ~200KB (exceeds target)
- **Compilation Speed**: Sub-second compilation enables fast iteration
- **Memory Safety**: Compile-time checks prevent common bugs
- **Concurrency**: Built-in channels and goroutines
- **Simplicity**: Small, consistent syntax easy to learn
- **C Interop**: Direct C function calls for wasmtime

### Negative
- **Maturity**: V is younger than Go/Rust, smaller ecosystem
- **Library Availability**: Fewer third-party libraries available
- **Hiring**: Smaller talent pool compared to Go/Java
- **Tooling**: Less mature IDE support than established languages

## Alternatives Considered

### Go
**Why not chosen:**
- Larger binary sizes (~10MB)
- GC pauses unacceptable for latency-sensitive workloads
- Less control over memory layout

### Rust
**Why not chosen:**
- Steeper learning curve
- Slower compilation times
- More complex for rapid prototyping

### C/C++
**Why not chosen:**
- Memory safety concerns
- Slower development velocity
- More code required for same functionality

### Zig
**Why not chosen:**
- Even younger than V
- Smaller community
- Less mature standard library

## References
- [V Language Comparison](https://vlang.io/compare)
- [V vs Go](https://github.com/vlang/v/wiki/V-vs-Go)
- [V vs Rust](https://github.com/vlang/v/wiki/V-vs-Rust)
