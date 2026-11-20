# Security Policy

**中文版：** [SECURITY.zh.md](SECURITY.zh.md)

## Supported versions

| Version | Supported |
|---------|-----------|
| `main` / 0.1.x | Yes (actively fixed) |
| Older archived tags | Best-effort |

Experimental modules (WASM simulation, some chain adapters, LLM) are **not** part of the security boundary for the default production path.

## Reporting a vulnerability

**Do not** post exploit details in public Issues.

Preferred order:

1. **GitHub Private vulnerability reporting**  
   Maintainers should enable: *Settings → Code security → Private vulnerability reporting*.  
   Report via the repo *Security* tab → *Report a vulnerability*.
2. If not enabled yet: email maintainers (About / org security contact), or
3. A private request that only states “there is an issue / module / version” (no full exploit)

Please include:

- Affected version / commit
- Reproduction steps or PoC (encrypted attachment OK)
- Impact assessment (RCE / disclosure / DoS / …)

We will acknowledge within a reasonable time and coordinate disclosure after a fix.

## Operator notes

- Replace all secrets in `deploy/.env.example` before deploying (`JWT_SECRET`, passwords, …)
- Default HTTP is minimal HTTP/1.1 **without TLS** — put a reverse proxy in front for production
- Never commit API keys or private keys
