# Deploy guide

**中文版：** [README.zh.md](README.zh.md)

Minimal local run without Docker:

```bash
# repo root
v run main.v
curl -s http://127.0.0.1:8080/health
```

Compose stacks are heavier (DB / Redis / monitoring). Prefer the binary path for a first OSS try. Image build entry is `main.v` (see `Dockerfile`). Before a release, smoke `docker compose config` / `up` on a clean machine.

## Quick deploy

```bash
cd deploy
cp .env.example .env   # rotate every password and JWT_SECRET

# Development
docker compose up -d
# Legacy CLI: docker-compose up -d

# Production compose file
docker compose -f docker-compose.prod.yml up -d
```

## Services

### Development

| Service | Port | Notes |
|---------|------|-------|
| vmodu-api | 8080 | Main API |
| postgres | 5432 | PostgreSQL |
| redis | 6379 | Redis |
| grafana | 3000 | Dashboards |

### Production (compose file)

- 3-node API cluster
- PostgreSQL primary/replica
- Redis Sentinel
- Nginx load balancer

## Environment

```bash
cp .env.example .env
# edit .env
```

| Variable | Purpose | Example |
|----------|---------|---------|
| `VMODU_ENV` | Environment | `production` |
| `VMODU_DB_HOST` | DB host | `postgres` |
| `VMODU_DB_PASSWORD` | DB password | *(rotate)* |
| `VMODU_JWT_SECRET` | JWT secret | *(rotate)* |

## Useful commands

```bash
docker compose logs -f
docker compose restart vmodu-api
docker compose down
docker compose down -v   # wipe volumes
```

## Database

```bash
docker exec vmodu-postgres pg_dump -U vmodu vmodu > backup.sql
cat backup.sql | docker exec -i vmodu-postgres psql -U vmodu
docker exec -it vmodu-postgres psql -U vmodu
```

## Monitoring

Defaults in the example compose (change before production):

- Grafana: http://localhost:3000 (often `admin`/`admin` in examples — **rotate**)
- Prometheus: http://localhost:9090

## Health

```bash
./scripts/health-check.sh
# or
curl http://localhost:8080/health
```

## Compose smoke (no containers)

Validates `docker-compose.yml` + env interpolation without starting services.
Safe when Docker is absent (prints `SKIP`, exits 0). Does not overwrite an existing `.env`.

```bash
cd deploy
./scripts/compose-smoke.sh
```

## Production checklist

- [ ] Replace all default passwords / secrets
- [ ] TLS certificates
- [ ] Firewall rules
- [ ] Log shipping
- [ ] Alerting rules
