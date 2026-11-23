# Contributing

Thanks for contributing to VModu.

**中文版：** [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md)

## Code of conduct

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Development setup

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu
v version   # requires V 0.5.2+
```

Smoke:

```bash
v -o /tmp/vmodu_main main.v
/tmp/vmodu_main &
curl -s http://127.0.0.1:8080/health
# stop the process when done
```

## Style

- Follow the [V docs](https://github.com/vlang/v/blob/master/doc/docs.md)
- `snake_case` for functions/vars; `PascalCase` for types
- Public API changes: update module docs / README module table
- Mark new experimental features clearly; do not claim production-ready by default

## Commit messages

```
type: short description

optional body
```

Common types: `feat` / `fix` / `docs` / `refactor` / `test` / `chore`.

## Tests

Avoid relying on `v test .` for the whole tree (multiple entry points / optional deps). Prefer:

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
v test vmodu/adapter/veb_adapter   # may hit fasthttp / compiler fallback
```

For docs-only changes, at least ensure links are not broken.

## CI

Pushes/PRs run [.github/workflows/ci.yml](.github/workflows/ci.yml): build `main.v`, health smoke, recommended unit tests. `veb_adapter` is best-effort.

## Pull requests

1. Fork and branch: `feature/...` or `fix/...`
2. Keep the diff focused; open an Issue first for large refactors
3. Fill [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md)
4. Link related Issues

## Security

Do not post exploit details publicly. See [SECURITY.md](SECURITY.md).

## License

Contributions are licensed under [MIT](LICENSE).
