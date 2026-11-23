# Production Hardening Wave 1 — Design

**Status:** Approved (user chose approach C / option 2)  
**Date:** 2026-11-21

## Goal

Raise core-path production score from ~4 toward **6–6.5** via minimal-break hardening + honest module narrowing. Raft persistence is **out of scope** (wave 2).

## Scope

| In | Out |
|----|-----|
| SQL Repository: stop string-concat values; SQLite-safe binding helpers | Full ORM rewrite / transactions |
| HTTP: `max_connections`, reject when full; graceful stop wait | App-level TLS |
| JWT: reject empty/short secret; constant-time sig compare | RS256 / key rotation |
| Mark payment / external MQ / chain / RPC gateway experimental; README honesty | Real Alipay RSA / Kafka |

## Approach

Minimal API breakage: keep `Pool.execute`/`query` for trusted DDL; add `exec_params`/`query_params` for user data; Repository uses placeholders. Document that raw `execute` with untrusted input remains unsafe.

## Success criteria

- Injection-style id cannot be interpolated as SQL syntax via Repository
- HTTP refuses excess concurrent connections; `stop` drains within timeout
- Empty JWT secret fails at manager construction or generate/verify
- README marks stub modules ⚠️; CI recommended subset still green
