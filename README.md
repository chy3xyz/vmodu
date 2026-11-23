# VModu

> Modular backend framework for the [V language](https://vlang.io) — documentation matches reality.

[![V Language](https://img.shields.io/badge/V-0.5.2+-blue.svg)](https://vlang.io)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![CI](https://github.com/chy3xyz/vmodu/actions/workflows/ci.yml/badge.svg)](https://github.com/chy3xyz/vmodu/actions/workflows/ci.yml)

**中文文档：** [README.zh.md](README.zh.md)

## What it is

VModu targets Actor-style and event-driven backends. HTTP listen and Raft `Transport` are real; WASM and some agent/chain paths remain **experimental** (see the module table).

**Solid today:** `core` container, `event/bus`, Actor runtime, and selected infra (HTTP, JWT, SQL pool, metrics, circuit, …).

## Quick start

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu

# Requires V 0.5.2+
v -prod -o vmodu main.v
./vmodu
```

```bash
curl -s http://127.0.0.1:8080/health
# {"status":"ok"}

curl -s http://127.0.0.1:8080/metrics | head
```

Full guide: [docs/quickstart.md](docs/quickstart.md).

Optional Docker: `cd deploy && cp .env.example .env && docker compose up -d` — see [deploy/README.md](deploy/README.md).

## Project layout

```
vmodu/
├── v.mod
├── vmodu/                 # library
│   ├── core/              # container / lifecycle
│   ├── event/             # event bus
│   ├── runtime/           # Actor runtime
│   ├── infra/             # HTTP / DB / cache / …
│   ├── adapter/veb_adapter/
│   ├── agent/             # LLM / planner (partially experimental)
│   ├── wasm/              # experimental (simulate by default)
│   └── cluster/           # Raft (Transport wired)
├── cmd/
├── docs/                  # current docs (archive/ is outdated)
└── deploy/
```

## Examples

### Actor (matches `vmodu/runtime/actor.v`)

```v
import vmodu.runtime

struct ProcessMsg {
	runtime.BaseMessage
	data string
}

fn main() {
	mut a := runtime.new_actor(runtime.ActorConfig{
		id:           'worker-1'
		mailbox_size: 100
	})
	a.start(fn (msg runtime.Message) {
		m := msg as ProcessMsg
		println(m.data)
	})
	a.send(ProcessMsg{
		BaseMessage: runtime.BaseMessage{ typ: 'process' }
		data:        'task data'
	})
}
```

### HTTP

Default entry `main.v` uses `infra/http` (`listen_tcp` + `/health` + `/metrics`).  
Alternatively use `adapter/veb_adapter` (see `docs/examples/`).

## Module status

| Module | Notes | Status |
|--------|-------|--------|
| `core` | Container / lifecycle | ✅ |
| `event/bus` | Event bus | ✅ |
| `runtime` | Actor runtime | ✅ |
| `adapter/veb_adapter` | veb HTTP adapter | ✅ |
| `infra/http` | Native HTTP + limits + request-id/trace hooks | ✅ |
| `infra/db/sql` | Pool + Tx + bound params (SQLite/MySQL/PG) | ✅ (per driver) |
| `infra/cache/redis` | Redis | ✅ |
| `infra/auth/jwt` | JWT | ✅ |
| `infra/metrics` | `/metrics` on default entry | ✅ |
| `infra/trace` | Span hooks + console/noop exporters | ✅ |
| `config` | `VMODU_*` runtime env loader | ✅ |
| `cluster/raft` | Transport + FileStorage / WalStorage + compact/snapshot | ✅ |
| `infra/payment` | Provider stubs; signing incomplete | ⚠️ experimental |
| `infra/mq` | InMemory OK; Rabbit/Kafka stubs | ⚠️ experimental |
| `infra/rpc` | RPC gateway scaffold | ⚠️ experimental |
| `adapters/evm` | EVM chain adapter stub | ⚠️ experimental |
| `adapters/solana` | Solana adapter stub | ⚠️ experimental |
| `wasm/sandbox` | Needs `VVMODU_WASM_SIMULATE=1` or `execute_simulated` | ⚠️ experimental |
| `wasm/wasmtime` | Stub — not a real wasmtime binding | ⚠️ experimental |
| `agent/llm` | HTTP client; `decompose` tries json2 | ⚠️ |

Legend: ✅ usable · ⚠️ experimental / not a default production path.

We do **not** publish unverified RPS claims.

## WASM (experimental)

- `wasm/sandbox` and `wasm/wasmtime` are **not** production WASM runtimes.
- `execute` errors unless `VVMODU_WASM_SIMULATE=1` is set.
- Tests/dev may call `execute_simulated()` explicitly.

## Documentation

| Doc | Language |
|-----|----------|
| [docs/README.md](docs/README.md) | English (default) |
| [docs/README.zh.md](docs/README.zh.md) | Chinese |
| [docs/quickstart.md](docs/quickstart.md) | English |
| [docs/architecture.md](docs/architecture.md) | English |
| [docs/api-reference.md](docs/api-reference.md) | English → module guide |
| [deploy/README.md](deploy/README.md) | English |
| [docs/archive/](docs/archive/) | Outdated historical material |

Deep module notes (Chinese-heavy today): [`vmodu/MODULES_GUIDE.md`](vmodu/MODULES_GUIDE.md). Production habits for **v0.2.0**: [`vmodu/BEST_PRACTICES.md`](vmodu/BEST_PRACTICES.md) · [中文](vmodu/BEST_PRACTICES.zh.md).

## Support matrix

| Component | Minimum | Notes |
|-----------|---------|--------|
| V compiler | 0.5.2+ | Validated against 0.5.2 |
| macOS / Linux | amd64 / arm64 | Windows best-effort |
| SQLite | via `db.sqlite` | Default local path |
| MySQL / PostgreSQL / Redis | optional | Need local libs/services |

## Contributing / security / license

- [CONTRIBUTING.md](CONTRIBUTING.md) · [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) · [CODE_OF_CONDUCT.zh.md](CODE_OF_CONDUCT.zh.md)
- [SECURITY.md](SECURITY.md) · [SECURITY.zh.md](SECURITY.zh.md)

- [MIT](LICENSE)

---

**VModu** — honest docs for real code.
