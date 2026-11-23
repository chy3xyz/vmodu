# Quick start

**中文版：** [quickstart.zh.md](quickstart.zh.md)

## Prerequisites

- **V 0.5.2+** ([install from source](https://github.com/vlang/v#installing-v-from-source))
- Optional: Docker (see `deploy/`)

```bash
v version   # expect V 0.5.2 or newer
```

## Clone and run

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu

# Dev
v run main.v

# Or production binary
v -prod -o vmodu main.v
./vmodu
```

Listens on `0.0.0.0:8080` by default. Override via env (see `vmodu/config/runtime.v`):

| Variable | Default | Meaning |
|----------|---------|---------|
| `VMODU_HTTP_HOST` | `0.0.0.0` | Bind address |
| `VMODU_HTTP_PORT` | `8080` | Listen port |
| `VMODU_MAX_CONNECTIONS` | `1024` | Max concurrent connections |
| `VMODU_RATE_LIMIT_RPS` | `1000` | Global rate limit (req/s) |
| `VMODU_RATE_LIMIT_BURST` | `200` | Global burst |
| `VMODU_IP_RATE_LIMIT_RPS` | `100` | Per-IP rate limit |
| `VMODU_IP_RATE_LIMIT_BURST` | `50` | Per-IP burst |
| `VMODU_RATE_LIMIT_PER_IP` | `true` | Enable per-IP buckets (`1`/`0`/`true`/`false`) |
| `VMODU_ACCESS_LOG` | `true` | JSON access log lines |
| `VMODU_TRACE` | `false` | `true`/`console` → console span export |

```bash
VMODU_HTTP_PORT=9090 v run main.v

curl -s http://127.0.0.1:8080/health
# {"status":"ok"}

curl -s http://127.0.0.1:8080/health/deep
# component aggregation JSON

curl -sD - http://127.0.0.1:8080/health -H 'X-Request-ID: demo' | head
# response includes X-Request-ID

curl -s http://127.0.0.1:8080/metrics | head
```

Compose config smoke (Docker optional):

```bash
bash deploy/scripts/compose-smoke.sh
```


> Default `main.v` uses a local metrics registry — usually **no** `-enable-globals` required.

## Docker (optional)

```bash
cd deploy
cp .env.example .env   # rotate secrets
docker compose up -d
```

See [deploy/README.md](../deploy/README.md). Do **not** assume fixed Grafana `admin/admin` unless your compose file says so.

## Scaffold a new app

```bash
cd cmd/vmodu-cli
v run . new myapp
cd ../../myapp   # or the path printed by the CLI
v run main.v
```

## Recommended tests (before contributing)

Whole-tree `v test .` may fail due to multiple mains / optional deps. Prefer:

```bash
v test vmodu/infra/http
v test vmodu/cluster/raft
v test vmodu/infra/auth
v test vmodu/infra/db/sql
v test vmodu/infra/pool
v test vmodu/infra/metrics
v test vmodu/infra/trace
v test vmodu/config
v test vmodu/event/bus
v test vmodu/infra/circuit
v test vmodu/agent/llm
v test vmodu/adapter/veb_adapter
```

## Next

- [Architecture](architecture.md)
- [API reference](api-reference.md)
- [Module status table](../README.md#module-status)
- [Contributing](../CONTRIBUTING.md)
