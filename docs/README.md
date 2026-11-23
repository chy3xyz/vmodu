# VModu documentation

Current docs for users and contributors.  
Anything under `archive/` is **outdated** by default.

**中文索引：** [README.zh.md](README.zh.md)

## Getting started

| Doc | Description |
|-----|-------------|
| [Quick start](quickstart.md) | Install V, build, health checks |
| [Architecture](architecture.md) | Modulith + Actor + EventBus |
| [API reference](api-reference.md) | Points to module guide |
| [Module guide](../vmodu/MODULES_GUIDE.md) · [ZH](../vmodu/MODULES_GUIDE.zh.md) | Per-module API (aligned with v0.2.0) |
| [Best practices](../vmodu/BEST_PRACTICES.md) · [ZH](../vmodu/BEST_PRACTICES.zh.md) | V 0.5.2 / v0.2.0 production habits |
| [Examples](examples/) | Sample apps |

## Deploy

| Doc | Description |
|-----|-------------|
| [Deploy guide](../deploy/README.md) | Docker Compose & env |
| [`.env.example`](../deploy/.env.example) | Copy to `.env` and rotate secrets |

## Project governance

| Doc | Description |
|-----|-------------|
| [Contributing](../CONTRIBUTING.md) | Branching, commits, recommended tests |
| [Security](../SECURITY.md) | Vulnerability reporting |
| [Code of conduct](../CODE_OF_CONDUCT.md) · [ZH](../CODE_OF_CONDUCT.zh.md) | Community norms |
| [Changelog](../CHANGELOG.md) | Release notes |
| [Maturity plan](plans/2026-11-20-maturity-9.5-swarm.md) | HTTP/Raft push notes |
| [Open-source checklist](OPEN_SOURCE_CHECKLIST.md) · [ZH](OPEN_SOURCE_CHECKLIST.zh.md) | Release readiness |

## Experimental

Marked ⚠️ in the root [README](../README.md) module table:

- `wasm/sandbox`, `wasm/wasmtime`
- parts of `agent/llm`
- `infra/payment`, `infra/mq` (external brokers; InMemory OK), `infra/rpc`
- `adapters/evm`, `adapters/solana`

## Archive

[`archive/`](archive/) holds old INSTALL / API / performance drafts.  
If it conflicts with source or current docs, **trust the code and this index**.
