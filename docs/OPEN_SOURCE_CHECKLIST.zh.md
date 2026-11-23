# 开源就绪检查清单

**English (default):** [OPEN_SOURCE_CHECKLIST.md](OPEN_SOURCE_CHECKLIST.md)

## 已完成

- [x] MIT LICENSE、诚实 README、docs 索引与 archive 声明
- [x] quickstart / CONTRIBUTING / SECURITY / CoC / Issue·PR 模板
- [x] CI、Dockerfile → `main.v`
- [x] **英文默认** + `.zh.md` 双语文档包
- [x] **Wave-1 诚实标注**：payment / 外部 MQ / RPC 网关 / EVM / Solana → ⚠️ experimental（SQL/HTTP/JWT 硬化为并行代码轨）

## 发布前（GitHub）

- [ ] 开启 Private vulnerability reporting
- [ ] 默认分支与 CI badge 一致
- [ ] 干净环境 `docker compose` 冒烟

## Wave 1 硬化（2026-11-21）

- [x] SQL 参数化 Repository（SQLite）+ 注入测
- [x] HTTP 连接上限 + stop 排空
- [x] JWT 最短密钥 + 恒定时间验签
- [x] payment / 外部 MQ / rpc / 链适配 experimental 标注
- [x] Wave 2：Raft FileStorage（term/vote/log）+ main 信号停机
- [x] Wave 3：SQL 事务 + MySQL/PG 绑定；Raft compact_log/install_snapshot
- [x] Wave 4：WalStorage append-only WAL；MySQL/PG 列名；HTTP 限流
- [x] Wave 5：按 IP 限流；429 指标；WAL fsync 策略
- [x] Wave 6：请求 ID + 访问日志；`/health/deep`；compose-smoke
- [x] Wave 7：HTTP trace 中间件；`VMODU_*` 配置；v0.2.0 切割
- [ ] 0.2 之后：GitHub Release；开启 Private vuln reporting；真实 compose up 冒烟






## 可选

- [ ] `MODULES_GUIDE` 全文英文化
- [ ] Release tag + 说明
- [ ] 第三方 NOTICE（若有非 MIT）
