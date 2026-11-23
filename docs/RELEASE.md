# Release cut — v0.2.0

## What’s in 0.2.0

Production-hardening waves 1–7 for the default HTTP path:

- Bound SQL params + transactions; MySQL/PG column names
- HTTP: connection limits, global + per-IP rate limits, request IDs, access logs, tracing hooks
- Raft: FileStorage, WalStorage (append-only + fsync mode), compact/snapshot
- Runtime config via `VMODU_*` env vars
- `/health`, `/health/deep`, `/metrics`
- Compose config smoke script + CI

## Tag locally (maintainers)

```bash
git tag -a v0.2.0 -m "v0.2.0 production hardening waves 1-7"
git push origin v0.2.0
gh release create v0.2.0 --title "v0.2.0" --notes-file docs/RELEASE.md
```

Do not force-push tags. Confirm CI green on `main` first.

## Env quick reference

See `docs/quickstart.md` and `deploy/.env.example` (`VMODU_HTTP_*`, rate limits, `VMODU_TRACE`, `VMODU_ACCESS_LOG`).
