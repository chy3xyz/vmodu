# VModu best practices

**中文版：** [BEST_PRACTICES.zh.md](BEST_PRACTICES.zh.md)

Target: **V 0.5.2+** and VModu **0.2.0+**. Prefer patterns that match the default entry (`main.v`) and the module status table in the root [README](../README.md). Experimental modules (WASM, chain adapters, payment stubs) are called out explicitly—do not treat them as production defaults.

---

## 1. Project layout

```
myapp/
├── v.mod
├── main.v                 # wire container + HTTP + health/metrics
├── config/                # optional JSON; prefer VMODU_* env for runtime
├── src/ or package dirs   # business modules
└── docs/
```

`v.mod` should declare a real dependency on this repo once published to your module path; for local work, use a path replace or `v` module search path.

Keep business logic in modules that implement `core.Module`. Put process wiring (ports, middleware, signal handlers) in `main.v` so tests can import packages without starting a full server.

---

## 2. Modules and errors

Implement `vmodu.core.Module` (`init` / `start` / `stop`). Prefer embedding `core.BaseModule` for name/version helpers.

```v
import vmodu.core
import vmodu.event.bus

pub struct UserModule {
	core.BaseModule
mut:
	bus &bus.EventBus = unsafe { nil }
}

pub fn (mut m UserModule) init(event_bus &bus.EventBus) ! {
	m.bus = event_bus
}

pub fn (mut m UserModule) start() ! {}
pub fn (mut m UserModule) stop() ! {}
```

Propagate errors with `!` / `or { return error('…: ${err}') }`. Do not swallow failures in `start`/`stop` without logging. Register modules on the container in dependency order: infra first, then domain, then HTTP route owners.

---

## 3. Actors

- One responsibility per actor; communicate with messages (`runtime.BaseMessage`), not shared `mut` maps across threads.
- Size mailboxes explicitly; supervise restarts via `runtime` supervisor APIs when you need fault isolation.
- Prefer bounded queues and back-pressure over unbounded growth.
- See root README Actor sample for `new_actor` / `start` / `send` shape.

---

## 4. Events

- Define topics and payload structs in one place.
- Subscribe in `Module.init` (or `start`); unsubscribe/cleanup in `stop` if the bus retains handlers.
- Keep handlers fast—offload heavy work to actors or a worker pool.
- Do not use the bus as a request/response RPC substitute; treat it as fire-and-forget or async fan-out.

---

## 5. HTTP (default production path)

Use `vmodu.infra.http` for the default stack.

| Concern | Practice |
|---------|----------|
| Bind address | `VMODU_HTTP_HOST` / `VMODU_HTTP_PORT` via `config.load_runtime_config()` |
| Connection cap | Set `max_connections` (default 1024); over limit → 503 |
| Rate limits | Global `rate_limit_rps` + per-IP `rate_limit_per_ip` |
| Identity | Propagate `X-Request-ID`; responses echo it |
| Tracing | `http.trace_middleware(tracer)`; enable export with `VMODU_TRACE=1` or `console` |
| Access logs | JSON lines when `access_log` / `VMODU_ACCESS_LOG` is on |
| TLS | Terminate at reverse proxy; app HTTP is plaintext by design |
| Liveness | `/health` cheap; `/health/deep` for component aggregation |
| Metrics | `/metrics` Prometheus text; track 429s via `rate_limited_total` |
| Shutdown | Handle `SIGINT`/`SIGTERM`; stop accepting, drain, then `Module.stop` (see `main.v`) |

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
```

Do not enable globals unless a third-party path truly requires `-enable-globals`. Put reverse-proxy timeouts above app idle timeouts so clients see clean 502/504 instead of hung sockets.

---

## 6. SQL and data

- Prefer `Pool.exec_params` / `query_params` (and `Tx` via `Pool.begin`) for any untrusted values.
- Identifiers (table/column) must be safe; Repository already validates simple idents and binds values with `?` (PostgreSQL rewrites to `$n`).
- Use transactions for multi-statement writes; always `commit` or `rollback`.
- Raw `execute` / `query` are for trusted DDL/admin only.
- SQLite is the well-tested default; MySQL/PG params are supported but validate against your driver install in CI.

```v
mut tx := pool.begin()!
tx.exec_params('INSERT INTO items (id, name) VALUES (?, ?)', [id, name])!
tx.commit()!
```

On failure paths, `rollback` before returning. Keep connection pools small in tests (`max_connections: 1` + shared `:memory:` or a temp file).

---

## 7. Auth (JWT)

- Secrets must be **≥ 16 characters** (`auth.min_jwt_secret_len`); load from env, never commit.
- Verification uses constant-time compare; keep HS256 unless you add a reviewed RS256 path.
- Short TTL for access tokens; rotate secrets operationally (app does not rotate yet).
- Reject empty/short secrets at process start, not only at first request.

---

## 8. Raft (when you need consensus)

- Inject a real `Transport` (`set_transport`); default `NilTransport` refuses fake success.
- Persist with `FileStorage` or append-only `WalStorage` (`set_storage` + `load_persistent` before `start`).
- Prefer `WalFsyncMode.every_write` in production; use `.none` only for local benchmarks.
- Call `compact_log` / `install_snapshot` to bound log growth; this is not a full streaming snapshot protocol.
- Multi-node membership / production ops still need your own deployment playbook.
- Never run consensus on ephemeral disks without a recovery story.

---

## 9. Observability

- Register `health.Checker` components that reflect real dependencies (DB ping, disk, upstream).
- Expose `/health` (liveness) and `/health/deep` (aggregated status → 503 when unhealthy).
- Export Prometheus metrics; include rate-limit counters if you care about client abuse.
- Structured access logs + optional console spans (`VMODU_TRACE`) are enough for a first production tier; full OpenTelemetry OTLP export is future work.
- Correlate logs with `X-Request-ID` when debugging a single client path.

---

## 10. Testing

Prefer focused package tests (same as CI):

```bash
v test vmodu/infra/http
v test vmodu/infra/db/sql
v test vmodu/infra/auth
v test vmodu/cluster/raft
v test vmodu/infra/trace
v test vmodu/config
```

- Avoid whole-tree `v test .` (multiple mains / optional deps).
- For HTTP tests, set `access_log: false` to keep output quiet.
- Use temp files / `:memory:` SQLite with `max_connections: 1` when schema must be shared.
- After changing rate limits or Raft storage, add a regression that fails without the fix.

---

## 11. Security and experimental modules

| Area | Do |
|------|----|
| Secrets | `VMODU_JWT_SECRET` and DB passwords only via env / secret store |
| WASM | Require `VVMODU_WASM_SIMULATE=1` or `execute_simulated`; not a real runtime |
| EVM / Solana / payment / external MQ / RPC gateway | Treat as **experimental**; isolate behind feature flags |
| Deploy | Run `bash deploy/scripts/compose-smoke.sh`; rotate `deploy/.env.example` values before `up` |
| Surface area | Do not expose experimental routes on the public listener |

---

## 12. Configuration

Use `config.load_runtime_config()` for process knobs. Full table lives in [docs/quickstart.md](../docs/quickstart.md); common keys:

| Variable | Default | Meaning |
|----------|---------|---------|
| `VMODU_HTTP_HOST` | `0.0.0.0` | Bind address |
| `VMODU_HTTP_PORT` | `8080` | Listen port |
| `VMODU_MAX_CONNECTIONS` | `1024` | Max concurrent connections |
| `VMODU_RATE_LIMIT_RPS` | `1000` | Global rate limit (req/s) |
| `VMODU_RATE_LIMIT_BURST` | `200` | Global burst |
| `VMODU_IP_RATE_LIMIT_RPS` | `100` | Per-IP rate limit |
| `VMODU_IP_RATE_LIMIT_BURST` | `50` | Per-IP burst |
| `VMODU_RATE_LIMIT_PER_IP` | `true` | Enable per-IP buckets |
| `VMODU_ACCESS_LOG` | `true` | JSON access log lines |
| `VMODU_TRACE` | `false` | `true`/`console` → console span export |

Do not invent a second config system for the same knobs. File-based `config.hot_reload` is optional for app-specific JSON—not a replacement for `VMODU_*` process env.

---

## 13. Anti-patterns

| Avoid | Prefer |
|-------|--------|
| String-building SQL with user input | `exec_params` / `query_params` |
| Relying on `NilTransport` “success” | Real `Transport` + durable storage |
| Shipping WASM / payment / chain adapters on by default | Feature flags + experimental label |
| `v test .` as the only CI gate | Per-package tests matching GitHub Actions |
| Secrets in repo or compose committed as live values | Env / secret store + rotate from `.env.example` |
| One giant `main` with no modules | `core.Module` lifecycle + thin entry |

---

## Checklist before shipping

- [ ] `/health` and `/health/deep` wired; deep checks cover real deps
- [ ] Rate limits and `max_connections` set for expected traffic
- [ ] JWT secret length ≥ 16; no secrets in git
- [ ] SQL paths use bound params + transactions where needed
- [ ] Raft nodes have Transport + durable storage if consensus matters
- [ ] `SIGINT`/`SIGTERM` stops the process cleanly
- [ ] CI package tests green; compose config smoke OK
- [ ] Experimental modules not on the default request path

---

## Related docs

- [Architecture](../docs/architecture.md) · [Quick start](../docs/quickstart.md) · [Release notes](../docs/RELEASE.md)
- [Module guide](MODULES_GUIDE.md) (CN-heavy API notes)
- [Deploy](../deploy/README.md) · [Security](../SECURITY.md) · [Open-source checklist](../docs/OPEN_SOURCE_CHECKLIST.md)
