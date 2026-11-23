# Open-source readiness checklist

**中文版：** [OPEN_SOURCE_CHECKLIST.zh.md](OPEN_SOURCE_CHECKLIST.zh.md)

## Done

- [x] MIT LICENSE
- [x] Honest README module table + support matrix
- [x] `docs/` index; `archive/` marked outdated
- [x] Quickstart aligned with `/health` + `/metrics`
- [x] API reference → `MODULES_GUIDE`
- [x] CONTRIBUTING recommended test paths
- [x] SECURITY.md / CODE_OF_CONDUCT.md
- [x] GitHub Issue / PR templates
- [x] `v.mod` description demarketed
- [x] GitHub Actions CI (build `main` + recommended tests + health smoke)
- [x] **English-default docs** + `.zh.md` companions (README, CONTRIBUTING, SECURITY, docs/*, deploy)
- [x] `dev/README.md` marked internal draft
- [x] Dockerfile builds `main.v`
- [x] SECURITY explains Private vulnerability reporting
- [x] **Wave-1 honesty labeling**: payment / external MQ / RPC gateway / EVM / Solana marked ⚠️ experimental in README + file banners (SQL/HTTP/JWT hardening is separate wave-1 code track)

## Before release (maintainers on GitHub)

- [x] Settings → Code security → **Private vulnerability reporting** = On
- [x] Default branch name matches CI badge (`main`)
- [ ] Clean-machine smoke: `cd deploy && cp .env.example .env && docker compose up -d` (trim services as needed)

## Wave 1 hardening (2026-11-21)

- [x] SQL parameterized Repository (SQLite) + injection test
- [x] HTTP max_connections + graceful drain on stop
- [x] JWT min secret length + constant-time verify
- [x] Experimental honesty for payment / mq brokers / rpc / chain adapters
- [x] Wave 2: Raft FileStorage (term/vote/log JSON); main signal shutdown
- [x] Wave 3: SQL Tx + MySQL/PG bind params; Raft compact_log/install_snapshot
- [x] Wave 4: WalStorage append-only WAL; MySQL/PG column names; HTTP rate limit
- [x] Wave 5: per-IP rate limit; 429 metrics; WAL fsync policy
- [x] Wave 6: request IDs + access log; `/health/deep`; compose-smoke script/CI
- [x] Wave 7: HTTP trace middleware; `VMODU_*` runtime config; v0.2.0 cut (`VERSION` / `docs/RELEASE.md`)
- [x] Post-0.2: GitHub Release + tag `v0.2.0` published
- [x] Post-0.2: Private vuln reporting on
- [ ] Post-0.2: live docker compose up smoke

## Optional

- [x] Best practices refreshed for v0.2.0 (EN default + `.zh.md`)
- [x] `MODULES_GUIDE` English-default + `.zh.md`, aligned with v0.2.0 APIs
- [ ] Third-party NOTICE if non-MIT deps land

