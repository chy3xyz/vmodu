# VModu module guide

**中文版：** [MODULES_GUIDE.zh.md](MODULES_GUIDE.zh.md)

Target: **V 0.5.2+**, VModu **0.2.0+**.  
Status legend matches the root [README](../README.md#module-status): ✅ usable · ⚠️ experimental (not a default production path).

For production habits (env, rate limits, SQL params, Raft durability), see [BEST_PRACTICES.md](BEST_PRACTICES.md).

---

## Architecture

Modulith layout under `vmodu/`: modules communicate via the event bus and optional intent routing. The default process entry is `main.v` (HTTP + health + metrics).

```
┌─────────────────────────────────────────────────────────────┐
│                        Application                          │
├──────────────────────────────┬──────────────────────────────┤
│ Agent (planner / tool / llm) │ Intent router                │
├──────────────────────────────┼──────────────────────────────┤
│ Adapters (evm / solana) ⚠️   │ WASM sandbox ⚠️              │
├──────────────────────────────┼──────────────────────────────┤
│ Runtime (actor / supervisor) │ Cluster (raft / node / shard)│
├──────────────────────────────┼──────────────────────────────┤
│ Core (modulith container)    │ Event bus                    │
├──────────────────────────────┴──────────────────────────────┤
│ Infra: http · sql · auth · health · metrics · trace · …     │
├─────────────────────────────────────────────────────────────┤
│ Config (VMODU_* runtime + optional JSON hot-reload)         │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Core — `vmodu.core` ✅

Lifecycle container for modules.

```v
import vmodu.core
import vmodu.event.bus

mut container := core.new_container()
container.with_event_bus(bus.default())
container.register('users', my_module)!
container.init()!
container.start()!
// …
container.stop()!
```

| Type / API | Role |
|------------|------|
| `Module` | `init` / `start` / `stop` |
| `BaseModule` | Embeddable name/version helpers (`new_base_module`) |
| `Container` | `register`, `get`, `list`, `init`, `start`, `stop` |

---

## 2. Runtime — `vmodu.runtime` ✅

Mailbox actors + supervisors.

```v
import vmodu.runtime

mut actor := runtime.new_actor(runtime.ActorConfig{
	id:           'worker-1'
	mailbox_size: 100
})
actor.start(fn (msg runtime.Message) {
	// handle
})
actor.send(runtime.BaseMessage{ /* … */ })
actor.try_send(runtime.BaseMessage{}) // non-blocking
actor.stop()
```

| API | Notes |
|-----|-------|
| `new_actor` / `send` / `try_send` / `send_with_timeout` | Bounded mailbox |
| `new_supervisor` / `add_child` / `supervise_actor` | Restart strategies |

Prefer messages over shared `mut` maps across threads. See [BEST_PRACTICES](BEST_PRACTICES.md#3-actors).

---

## 3. Event bus — `vmodu.event.bus` ✅

Pub/sub with byte payloads (not typed `Event` structs).

```v
import vmodu.event.bus

mut b := bus.default()
b.subscribe('user.created', fn (msg bus.Message) {
	_ = msg.payload
})!
b.publish('user.created', 'user-1'.bytes())!
```

| API | Notes |
|-----|-------|
| `new_event_bus` / `default` | Configured or default bus |
| `subscribe` / `subscribe_wildcard` / `unsubscribe` | Handlers |
| `publish` / `publish_with_headers` | Fire-and-forget |

Keep handlers fast; offload heavy work to actors.

---

## 4. Intent — `vmodu.intent` ✅

Command-style routing (`action` + params). Useful for agent/tool entry points; not required for HTTP apps.

```v
import vmodu.intent

mut i := intent.new_intent('swap')
i.with_param('from_token', 'ETH')
mut router := intent.new_router()
router.register(my_handler)
_ := router.route(i)
```

---

## 5. HTTP — `vmodu.infra.http` ✅

**Default production path** used by `main.v`.

```v
import vmodu.config { load_runtime_config }
import vmodu.infra.http
import vmodu.infra.trace

rt := load_runtime_config()
mut server := http.new_server(http.ServerConfig{
	host:                rt.http_host
	port:                rt.http_port
	max_connections:     rt.max_connections
	rate_limit_rps:      rt.rate_limit_rps
	rate_limit_burst:    rt.rate_limit_burst
	rate_limit_per_ip:   rt.rate_limit_per_ip
	ip_rate_limit_rps:   rt.ip_rate_limit_rps
	ip_rate_limit_burst: rt.ip_rate_limit_burst
	access_log:          rt.access_log
})
server.use(http.trace_middleware(trace.new_tracer('myapp', trace.new_noop_exporter())))
server.get('/ping', fn (ctx http.Context) !http.Response {
	mut r := http.new_response()
	r.text('pong')
	return r
})
server.start()!
```

| Concern | Behavior (0.2) |
|---------|----------------|
| Connection cap | `max_connections`; over limit → **503** (slot reserved under lock before `spawn`) |
| Rate limit | Global + optional per-IP; over → **429**, counted in `rate_limited_total` |
| Request ID | `X-Request-ID` in/out |
| Access log | JSON lines when `access_log` / `VMODU_ACCESS_LOG` |
| Trace | `http.trace_middleware`; `VMODU_TRACE=1\|console` |

Also: `adapter/veb_adapter` ✅ for veb-based apps (see `docs/examples/`).

---

## 6. SQL — `vmodu.infra.db.sql` ✅ (per driver)

```v
import vmodu.infra.db.sql

mut pool := sql.new_pool(sql.Config{
	db_type:        .sqlite
	database:       'app.db'
	max_connections: 4
})!
defer { pool.close() }

pool.exec_params('INSERT INTO items (id, name) VALUES (?, ?)', [id, name])!
rows := pool.query_params('SELECT id, name FROM items WHERE id = ?', [id])!

mut tx := pool.begin()!
tx.exec_params('UPDATE items SET name = ? WHERE id = ?', [name2, id])!
tx.commit()!
```

| API | Use |
|-----|-----|
| `exec_params` / `query_params` | Bound values (`?`; PG rewritten to `$n`) |
| `Pool.begin` → `Tx` | Multi-statement writes; always `commit` / `rollback` |
| `execute` / `query` | Trusted DDL/admin only |
| `Repository[T]` | Simple CRUD with identifier validation |

SQLite is the best-tested default; MySQL/PostgreSQL need local libs + CI coverage.

---

## 7. Auth (JWT) — `vmodu.infra.auth` ✅

```v
import vmodu.infra.auth

mut jwt := auth.new_jwt_manager(auth.JWTConfig{
	secret:     os.getenv('VMODU_JWT_SECRET') // length ≥ auth.min_jwt_secret_len (16)
	issuer:     'myapp'
	access_ttl: 3600
})
token := jwt.generate(user_id, ['user'], ['read'])!
payload := jwt.verify(token)!
```

Verification uses constant-time compare. Empty/short secrets fail on `generate` / `verify`.

---

## 8. Health / metrics / trace ✅

### Health — `vmodu.infra.health`

```v
import vmodu.infra.health

mut checker := health.default_checker()
checker.register('database', fn () health.ComponentHealth {
	return health.ComponentHealth{
		name:    'database'
		status:  .healthy
		message: 'ok'
	}
})!
report := checker.run_checks()
```

Default entry exposes `/health` (liveness) and `/health/deep` (aggregated; unhealthy → 503).

### Metrics — `vmodu.infra.metrics`

```v
import vmodu.infra.metrics

mut registry := metrics.new_registry('myapp')
mut c := registry.new_counter('http_requests_total', 'HTTP requests', {})!
c.inc()
text := metrics.new_exporter(registry).export() // Prometheus text; served at /metrics
```

### Trace — `vmodu.infra.trace`

```v
import vmodu.infra.trace

mut tracer := trace.new_tracer('myapp', trace.new_console_exporter(false))
mut span := tracer.start_span('work', trace.SpanOptions{})
span.set_attribute('key', 'value')
tracer.finish(mut span)
```

Exporters: `NoopExporter`, `ConsoleExporter`, `InMemoryExporter`, `BatchExporter`. Full OTLP export is future work.

---

## 9. Raft — `vmodu.cluster.raft` ✅

```v
import vmodu.cluster.raft

mut node := raft.new_node('n1', ['n2', 'n3'])
mut transport := raft.MemoryTransport{} // or real Transport wrapping rpc.Client
node.set_transport(mut transport)

mut storage := raft.new_wal_storage_opts('/var/lib/vmodu/raft', .every_write)
node.set_storage(mut storage)
node.load_persistent()!
node.start()
// later: node.compact_log(idx)! / node.install_snapshot(idx, term, data)!
```

| Piece | Notes |
|-------|-------|
| `Transport` | Required; default `NilTransport` refuses fake success |
| `FileStorage` | JSON durable state |
| `WalStorage` | Append-only WAL; prefer `WalFsyncMode.every_write` in production |
| `compact_log` / `install_snapshot` | Bound log growth (not a full streaming snapshot protocol) |

`cluster/node` and `cluster/shard` provide higher-level cluster/sharding helpers; treat multi-node ops as your own playbook.

---

## 10. Config — `vmodu.config` ✅

**Process env (preferred for HTTP runtime):**

```v
import vmodu.config { load_runtime_config }

rt := load_runtime_config() // VMODU_HTTP_*, VMODU_RATE_*, VMODU_ACCESS_LOG, VMODU_TRACE, …
```

See [docs/quickstart.md](../docs/quickstart.md) for the full env table.

**Optional JSON + watch:** `config.new_manager()` / `load` / `start_watching` — app-specific file config, not a replacement for `VMODU_*`.

---

## 11. Circuit / pool / other infra ✅ / varies

| Module | Status | Summary |
|--------|--------|---------|
| `infra/circuit` | ✅ | Breaker around fallible calls |
| `infra/pool` | ✅ | Generic connection pool |
| `infra/logger` | ✅ | Structured logging helpers |
| `infra/cache` (Redis) | ✅ | When Redis libs available |
| `infra/ws` | usable / evolving | WebSocket server helpers |
| `infra/mq` | ⚠️ | InMemory OK; Rabbit/Kafka stubs |
| `infra/rpc` | ⚠️ | Gateway scaffold |
| `infra/payment` | ⚠️ | Provider stubs |

---

## 12. Agent — `vmodu.agent.*` ⚠️ / partial

| Module | Notes |
|--------|-------|
| `agent/tool` | Tool registry |
| `agent/planner` | Task → plan decomposition |
| `agent/llm` | HTTP LLM client; `decompose` parses JSON via json2 — treat as evolving |

Do not put agent/LLM on the default public request path without auth and quotas.

---

## 13. Adapters & WASM ⚠️ experimental

| Module | Gate |
|--------|------|
| `adapters/evm`, `adapters/solana` | Stubs — feature-flag only |
| `wasm/sandbox` | `execute` errors unless `VVMODU_WASM_SIMULATE=1`; prefer `execute_simulated` in tests |
| `wasm/wasmtime` | Stub — not a real wasmtime binding |

---

## Dependency rules

1. Upper layers may depend on lower layers.
2. Same-layer modules should prefer the event bus over hard imports when possible.
3. No cycles.
4. Experimental modules must not sit on the default listener without an explicit flag.

```
config
  ↑
core ←→ event/bus ←→ intent
  ↑         ↑
runtime ←→ cluster/raft
  ↑
agent / adapters ⚠️
  ↑
infra/http · sql · auth · health · metrics · trace
```

---

## Minimal app sketch

```v
module main

import vmodu.core { new_container }
import vmodu.config { load_runtime_config }
import vmodu.infra.http
import vmodu.infra.health

fn main() {
	mut container := new_container()
	container.start()!

	rt := load_runtime_config()
	mut checker := health.default_checker()
	_ = checker

	mut server := http.new_server(http.ServerConfig{
		host: rt.http_host
		port: rt.http_port
		access_log: false
	})
	server.get('/health', fn (ctx http.Context) !http.Response {
		mut r := http.new_response()
		r.json({'status': 'ok'})
		return r
	})
	server.start()!
}
```

Or run the shipped entry: `v run main.v` (wires metrics, deep health, rate limits, SIGINT/SIGTERM).

---

## Related docs

- [Best practices](BEST_PRACTICES.md) · [Architecture](../docs/architecture.md) · [Quick start](../docs/quickstart.md)
- [API reference](../docs/api-reference.md) (points here) · [Release notes](../docs/RELEASE.md)
- [Security](../SECURITY.md)
