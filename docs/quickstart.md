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

Listens on `0.0.0.0:8080`:

```bash
curl -s http://127.0.0.1:8080/health
# {"status":"ok"}

curl -s http://127.0.0.1:8080/metrics | head
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
