# Production Hardening Wave 1 — Implementation Plan

> **For agentic workers:** Execute tasks in parallel where noted. Prefer TDD. Do not commit unless user asks.

**Goal:** Core harden (SQL/HTTP/JWT) + honest experimental labeling.

**Files:**
- `vmodu/infra/db/sql/db.v`, `sql_test.v`
- `vmodu/infra/http/server.v`, `server_test.v`
- `vmodu/infra/auth/jwt.v`, `jwt_test.v`
- `main.v`
- `vmodu/infra/payment/payment.v`, `vmodu/infra/mq/mq.v`, `vmodu/infra/rpc/rpc.v`, adapters headers
- `README.md`, `README.zh.md`, `CHANGELOG.md`, checklist

## Task A — SQL (parallel track 1)

1. Add `Pool.exec_params` / `query_params` for SQLite (`?` placeholders); MySQL/PG return clear error or best-effort.
2. Rewrite Repository find/save/delete to use params; never quote-interpolate values.
3. Improve `sqlite_rows_to_rows` enough for tests.
4. Tests: create table, save/find with id containing `' OR 1=1 --`; assert safe behavior.

## Task B — HTTP (parallel track 2)

1. `ServerConfig.max_connections` default 1024; track active; over limit close with 503.
2. `stop_timeout`; stop closes listener then waits `requests_active==0` or timeout.
3. Tests for limit + stop.
4. Wire `main.v` defaults.

## Task C — JWT (parallel track 3)

1. `min_secret_len` (e.g. 16); `new_jwt_manager` or generate/verify errors if too short.
2. Constant-time compare of signature bytes.
3. Tests for empty secret + tampered sig still fails.

## Task D — Honesty (parallel track 4)

1. Module file banners: experimental / not production.
2. README status table: payment, mq (external), rpc, evm, solana → ⚠️.
3. CHANGELOG + checklist note wave 1 done; Raft persistence = next.
