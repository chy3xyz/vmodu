# VModu

> 基于 V 语言的模块化后端框架（文档与实现对齐）

[![V Language](https://img.shields.io/badge/V-0.5.2+-blue.svg)](https://vlang.io)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![CI](https://github.com/chy3xyz/vmodu/actions/workflows/ci.yml/badge.svg)](https://github.com/chy3xyz/vmodu/actions/workflows/ci.yml)

**English (default):** [README.md](README.md)

## 简介

VModu 面向 Actor / 事件驱动风格的后端开发。HTTP listen 与 Raft `Transport` 已真实化；WASM 等仍为实验项。请以模块状态表为准，勿把 ⚠️ 项当作生产就绪。

**已可用方向：**

- 模块容器与生命周期（`core`）
- 事件总线（`event/bus`）
- Actor 运行时与监督树（`runtime`）
- 常用 infra 组件（DB / cache / JWT 等，成熟度不一）

## 快速开始

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu

# 需本机已安装 V 0.5.2+
v -prod -o vmodu main.v
./vmodu
```

另开终端：`curl -s http://127.0.0.1:8080/health` → `{"status":"ok"}`；`/metrics` 为 Prometheus 文本。

更完整步骤见 [docs/quickstart.zh.md](docs/quickstart.zh.md)（英文默认版：[docs/quickstart.md](docs/quickstart.md)）。

Docker（可选）：

```bash
cd deploy && cp .env.example .env && docker compose up -d
```

## 模块状态（诚实表）

| 模块 | 说明 | 状态 |
|------|------|------|
| `core` | 模块容器与生命周期 | ✅ |
| `event/bus` | 事件总线 | ✅ |
| `runtime` | Actor 运行时 | ✅ |
| `adapter/veb_adapter` | 基于 veb 的 HTTP 适配 | ✅ |
| `infra/http` | 自研 HTTP + 连接/全局限流/按 IP 限流 | ✅ |
| `infra/db/sql` | 连接池 + 事务 + 绑定参数（SQLite/MySQL/PG） | ✅（按驱动验证） |
| `infra/cache/redis` | Redis 缓存 | ✅ |
| `infra/auth/jwt` | JWT | ✅ |
| `infra/metrics` | 默认入口 `/metrics` | ✅ |
| `cluster/raft` | Transport + FileStorage/WalStorage + compact/snapshot | ✅ |
| `infra/payment` | 支付网关桩；签名未完成 | ⚠️ experimental |
| `infra/mq` | InMemory 可用；Rabbit/Kafka 为桩 | ⚠️ experimental |
| `infra/rpc` | RPC 网关脚手架 | ⚠️ experimental |
| `adapters/evm` | EVM 链适配桩 | ⚠️ experimental |
| `adapters/solana` | Solana 适配桩 | ⚠️ experimental |
| `wasm/*` | 非生产 WASM 运行时 | ⚠️ experimental |
| `agent/llm` | LLM 客户端 | ⚠️ |

图例：✅ 可用 · ⚠️ 实验 / 勿当生产默认路径。仓库不提供未验证的 RPS 宣传数据。

## 文档

- 英文默认索引：[docs/README.md](docs/README.md)
- 中文索引：[docs/README.zh.md](docs/README.zh.md)
- [模块指南](vmodu/MODULES_GUIDE.zh.md)（[EN](vmodu/MODULES_GUIDE.md)）· [最佳实践](vmodu/BEST_PRACTICES.zh.md)（[EN](vmodu/BEST_PRACTICES.md)）· [贡献](CONTRIBUTING.zh.md) · [安全](SECURITY.zh.md) · [MIT](LICENSE)

---

**VModu** — 以诚实文档匹配真实实现。
