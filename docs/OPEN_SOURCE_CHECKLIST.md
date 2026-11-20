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

## Before release (maintainers on GitHub)

- [ ] Settings → Code security → **Private vulnerability reporting** = On
- [ ] Default branch name matches CI badge (`main` / `master`)
- [ ] Clean-machine smoke: `cd deploy && cp .env.example .env && docker compose up -d` (trim services as needed)

## Optional

- [ ] Full English pass on `MODULES_GUIDE` / `BEST_PRACTICES`
- [ ] Release tag + GitHub Release notes
- [ ] Third-party NOTICE if non-MIT deps land
