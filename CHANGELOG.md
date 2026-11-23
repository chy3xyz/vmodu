# Changelog

All notable changes to VModu Runtime will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- (none yet)

## [0.2.0] - 2026-11-23

### Added
- Spec/plan: `docs/superpowers/specs/2026-11-21-production-hardening-design.md`, `docs/superpowers/plans/2026-11-21-production-hardening.md`.
- `VERSION`, `docs/RELEASE.md`; runtime env config (`vmodu/config/runtime.v`).
- HTTP tracing middleware (`trace_middleware`) + `Tracer.finish` / `NoopExporter`.

### Changed
- **Waves 1–7 production hardening** (SQL params/Tx, HTTP limits/rate/IP/429/request-id/access-log/trace, Raft FileStorage/WAL/snapshot, `/health/deep`, compose-smoke, `VMODU_*` env, version **0.2.0**).
- Honesty labeling: payment / external MQ / rpc / chain adapters → ⚠️ experimental.







### Added
- GitHub Actions CI; English-default bilingual OSS docs (`README.md` + `*.zh.md` companions).

### Changed
- Dockerfile builds `main.v`; SECURITY documents Private vulnerability reporting setup.
- Docs language policy: English default, Chinese via `.zh.md` (removed obsolete `README.en.md`).



### Added
- Open-source docs pack: SECURITY.md, CODE_OF_CONDUCT.md, GitHub Issue/PR templates, docs index refresh, api-reference stub.

### Changed
- README / quickstart / CONTRIBUTING aligned for V 0.5.2; v.mod description demarketed; archive marked outdated.


### Changed
- Maturity swarm: real HTTP listen + Raft Transport, critical tests, honest docs; default `/health` + `/metrics` (use `v -enable-globals`).


### Changed
- **Maturity honesty push (2026-11-20)**: README module table no longer marks HTTP/Raft/WASM as production ✅; removed unverified RPS claims; Actor sample aligned with `runtime/actor.v`.
- WASM `sandbox` / `wasmtime`: marked experimental; `execute` errors unless `VVMODU_WASM_SIMULATE=1` (or use `execute_simulated`).
- LLM `decompose`: parse plan steps via `json2` when possible; safe default fallback if JSON invalid.
- Adapt to V 0.5.2: migrate `json` → `json2`, old generics `<T>` → `[T]`, `hmac.new_sha256` → `hmac.new`, veb adapter for modern Middleware API, and related stdlib API updates (`sqlite.connect`, `pg.connect` pool, http headers).

### Added
- Distributed actor cluster support (planned)
- Real WASM runtime integration (wasmtime) (planned — current code is a stub)
- LLM API integration (OpenAI/Claude) (partial; decompose JSON parsing added)
- Prometheus metrics export (planned)
- Hot module reload (planned)

## [2.0.0] - 2025-XX-XX

### Added - Phase 5: Production Extensions
- RPC Gateway with HTTP/gRPC support
- Middleware pipeline (auth, logging, rate limiting)
- Request/response validation

### Added - Phase 4: AI Integration
- Agent Planner with task decomposition
- Rule-based planning engine
- Tool dependency resolution
- Plan execution with context tracking

### Added - Phase 3: Web3 Support
- EVM Adapter (Ethereum mainnet, testnet support)
- Solana Adapter (mainnet-beta, devnet support)
- Transaction building and simulation
- Token account queries (SPL tokens)
- Event monitoring interfaces

### Added - Phase 2: Scale
- Actor Scheduler with work-stealing
- Configurable worker pools (16 workers default)
- Priority-based scheduling
- Actor lifecycle management
- Event Store with Kafka-like persistence
- Append-only logs with offsets
- Multi-log support
- Event replay capabilities
- WASM Sandbox for secure execution
- Memory limits (16MB default)
- CPU time limits (5s default)
- Tool interface for WASM modules

### Added - Phase 1: Core
- Actor Runtime with mailbox pattern
- Lock-free message passing via channels
- Goroutine-based concurrency
- EventBus with pub/sub pattern
- Async event delivery
- Intent Protocol with type-safe routing
- Default handler support
- Agent Runtime with Tool interface
- Memory system for context
- Module system with interfaces
- Container for module management

## [1.0.0] - 2025-XX-XX

### Added - Initial Release
- Basic actor implementation
- Simple event bus
- Intent routing
- Basic documentation

---

## Release Planning

> Honesty note (2026-11-20): items below were previously marked “Complete” while several remain stubs/planned. Status rewritten.

### v2.1.0 (partial / planned)
- [ ] Real WASM runtime (wasmtime C bindings) — **stub** today; see `VVMODU_WASM_SIMULATE`
- [~] LLM API client — present; plan decompose now parses JSON via json2
- [ ] Persistent event storage (file-based with segments)
- [ ] WebSocket support in RPC Gateway

### v2.2.0 (partial / planned)
- [ ] Distributed actor cluster
- [~] Raft consensus — code present; some paths still simulate (swarm Agent B)
- [ ] Actor migration between nodes
- [ ] Sharding support (consistent hashing)

### v3.0.0 (planned)
- [ ] Hot module reload (file watching)
- [ ] Plugin system (dynamic loading)
- [ ] GraphQL API
- [ ] Admin dashboard (metrics, alerts)

---

## Contributing to Changelog

When submitting PRs, please add entries under the `[Unreleased]` section:

```markdown
### Added
- New feature X

### Changed
- Modified behavior Y

### Fixed
- Bug Z

### Deprecated
- Old API

### Removed
- Deleted feature

### Security
- Security fix
```
