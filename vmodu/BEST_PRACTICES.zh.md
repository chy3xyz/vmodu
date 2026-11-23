# VModu 最佳实践

**English (default):** [BEST_PRACTICES.md](BEST_PRACTICES.md)

面向 **V 0.5.2+**、VModu **0.2.0+**。做法对齐默认入口（`main.v`）与根 [README](../README.md) 模块状态表。WASM / 链适配 / 支付骨架等为实验项，勿当默认生产路径。

---

## 1. 项目结构

```
myapp/
├── v.mod
├── main.v                 # 组装容器 + HTTP + health/metrics
├── config/                # 可选 JSON；运行时优先 VMODU_* 环境变量
├── src/ 或包目录           # 业务模块
└── docs/
```

`v.mod` 在模块路径发布后应声明真实依赖；本地开发可用 path replace 或 `v` 模块搜索路径。

业务逻辑放在实现 `core.Module` 的模块里；端口、中间件、信号等进程接线放在 `main.v`，便于单测只导入包而不拉起整站。

---

## 2. 模块与错误

实现 `vmodu.core.Module`（`init` / `start` / `stop`）。可嵌入 `core.BaseModule` 获得名称/版本辅助。

```v
import vmodu.core
import vmodu.event.bus

pub struct UserModule {
	core.BaseModule
mut:
	bus &bus.EventBus = unsafe { nil }
}

pub fn (mut m UserModule) init(event_bus &bus.EventBus) ! {
	m.bus = event_bus
}

pub fn (mut m UserModule) start() ! {}
pub fn (mut m UserModule) stop() ! {}
```

用 `!` / `or { return error('…: ${err}') }` 传播错误；`start`/`stop` 里不要静默吞掉失败。按依赖顺序注册：基础设施 → 领域 → 路由所有者。

---

## 3. Actor

- 单职责；用消息（`runtime.BaseMessage`）通信，避免跨协程共享 `mut` 映射。
- 邮箱容量显式配置；需要故障隔离时用 `runtime` supervisor。
- 优先有界队列与背压，避免无界堆积。
- 形状见根 README 的 Actor 示例（`new_actor` / `start` / `send`）。

---

## 4. 事件

- 主题与载荷结构体集中定义。
- 在 `Module.init`（或 `start`）订阅；若总线长期持有处理器，在 `stop` 里退订/清理。
- 处理器保持轻量——重活丢给 Actor 或工作池。
- 不要把 EventBus 当请求/响应 RPC；按 fire-and-forget 或异步扇出使用。

---

## 5. HTTP（默认生产路径）

默认栈用 `vmodu.infra.http`。

| 关注点 | 做法 |
|--------|------|
| 绑定地址 | `VMODU_HTTP_HOST` / `VMODU_HTTP_PORT`，经 `config.load_runtime_config()` |
| 连接上限 | 设 `max_connections`（默认 1024）；超额 → 503 |
| 限流 | 全局 `rate_limit_rps` + 按 IP 的 `rate_limit_per_ip` |
| 身份 | 透传 `X-Request-ID`；响应回写 |
| 追踪 | `http.trace_middleware(tracer)`；`VMODU_TRACE=1` 或 `console` 开启导出 |
| 访问日志 | `access_log` / `VMODU_ACCESS_LOG` 开启时输出 JSON 行 |
| TLS | 在反向代理终止；应用层默认明文 |
| 存活 | `/health` 轻量；`/health/deep` 组件聚合 |
| 指标 | `/metrics` Prometheus 文本；429 计入 `rate_limited_total` |
| 停机 | 处理 `SIGINT`/`SIGTERM`；停接新连接 → 排空 → `Module.stop`（见 `main.v`） |

```v
import vmodu.config { load_runtime_config }
import vmodu.infra.http
import vmodu.infra.trace

rt := load_runtime_config()
mut server := http.new_server(http.ServerConfig{
	host:                rt.http_host
	port:                rt.http_port
	max_connections:     rt.max_connections
	rate_limit_rps:      rt.rate_limit_rps
	rate_limit_burst:    rt.rate_limit_burst
	rate_limit_per_ip:   rt.rate_limit_per_ip
	ip_rate_limit_rps:   rt.ip_rate_limit_rps
	ip_rate_limit_burst: rt.ip_rate_limit_burst
	access_log:          rt.access_log
})
server.use(http.trace_middleware(trace.new_tracer('myapp', trace.new_noop_exporter())))
```

除非第三方路径确实需要，否则不要开 `-enable-globals`。反向代理超时应大于应用空闲超时，避免客户端挂死套接字。

---

## 6. SQL 与数据

- 不可信输入一律用 `Pool.exec_params` / `query_params`（事务用 `Pool.begin` → `Tx`）。
- 表名/列名须安全；Repository 已校验简单标识符，值用 `?` 绑定（PostgreSQL 改写为 `$n`）。
- 多语句写操作走事务；务必 `commit` 或 `rollback`。
- 裸 `execute` / `query` 仅用于可信 DDL/运维。
- SQLite 是验证最充分的默认路径；MySQL/PG 参数已支持，但要在 CI 里对照本机驱动验证。

```v
mut tx := pool.begin()!
tx.exec_params('INSERT INTO items (id, name) VALUES (?, ?)', [id, name])!
tx.commit()!
```

失败路径先 `rollback` 再返回。测试里池可缩小（`max_connections: 1` + 共享 `:memory:` 或临时文件）。

---

## 7. 鉴权（JWT）

- 密钥长度 **≥ 16**（`auth.min_jwt_secret_len`）；从环境变量加载，勿提交仓库。
- 验签为恒定时间比较；在未评审 RS256 前保持 HS256。
- 访问令牌短 TTL；密钥轮换靠运维（应用尚未内置轮换）。
- 进程启动即拒绝空/过短密钥，不要等到第一次请求。

---

## 8. Raft（需要共识时）

- 注入真实 `Transport`（`set_transport`）；默认 `NilTransport` 不会假装成功。
- 持久化用 `FileStorage` 或追加型 `WalStorage`（`set_storage` + 在 `start` 前 `load_persistent`）。
- 生产倾向 `WalFsyncMode.every_write`；`.none` 仅用于本地压测。
- 用 `compact_log` / `install_snapshot` 控制日志膨胀；这不是完整流式快照协议。
- 多节点成员变更与生产运维仍需自备部署手册。
- 不要在无恢复方案的临时盘上跑共识。

---

## 9. 可观测性

- 注册反映真实依赖的 `health.Checker`（DB ping、磁盘、上游）。
- 暴露 `/health`（存活）与 `/health/deep`（聚合；不健康 → 503）。
- 导出 Prometheus；关注滥用时带上限流计数。
- 结构化访问日志 + 可选控制台 span（`VMODU_TRACE`）足以支撑第一档生产；完整 OTLP 导出属后续工作。
- 排障时用 `X-Request-ID` 关联单次客户端路径。

---

## 10. 测试

优先按包测（与 CI 一致）：

```bash
v test vmodu/infra/http
v test vmodu/infra/db/sql
v test vmodu/infra/auth
v test vmodu/cluster/raft
v test vmodu/infra/trace
v test vmodu/config
```

- 避免整树 `v test .`（多 `main` / 可选依赖）。
- HTTP 单测可关 `access_log` 降噪。
- 需要共享 schema 时用临时文件 / `:memory:` SQLite，并设 `max_connections: 1`。
- 改限流或 Raft 存储后，补一条没有修复就会失败的回归。

---

## 11. 安全与实验模块

| 领域 | 做法 |
|------|------|
| 密钥 | `VMODU_JWT_SECRET` 与 DB 密码仅经环境 / 密钥仓 |
| WASM | 需 `VVMODU_WASM_SIMULATE=1` 或 `execute_simulated`；非真实运行时 |
| EVM / Solana / payment / 外部 MQ / RPC gateway | 视为 **experimental**；用特性开关隔离 |
| 部署 | 跑 `bash deploy/scripts/compose-smoke.sh`；`up` 前轮换 `deploy/.env.example` 中的值 |
| 暴露面 | 勿把实验路由挂到公网监听上 |

---

## 12. 配置

进程级旋钮用 `config.load_runtime_config()`。完整表见 [docs/quickstart.md](../docs/quickstart.md)；常用键：

| 变量 | 默认 | 含义 |
|------|------|------|
| `VMODU_HTTP_HOST` | `0.0.0.0` | 绑定地址 |
| `VMODU_HTTP_PORT` | `8080` | 监听端口 |
| `VMODU_MAX_CONNECTIONS` | `1024` | 最大并发连接 |
| `VMODU_RATE_LIMIT_RPS` | `1000` | 全局限流（req/s） |
| `VMODU_RATE_LIMIT_BURST` | `200` | 全局突发 |
| `VMODU_IP_RATE_LIMIT_RPS` | `100` | 按 IP 限流 |
| `VMODU_IP_RATE_LIMIT_BURST` | `50` | 按 IP 突发 |
| `VMODU_RATE_LIMIT_PER_IP` | `true` | 启用按 IP 桶 |
| `VMODU_ACCESS_LOG` | `true` | JSON 访问日志 |
| `VMODU_TRACE` | `false` | `true`/`console` → 控制台 span |

不要为同一组旋钮再造第二套配置系统。文件型 `config.hot_reload` 仅用于应用自定义 JSON——不能替代 `VMODU_*` 进程环境变量。

---

## 13. 反模式

| 避免 | 改为 |
|------|------|
| 用用户输入拼接 SQL | `exec_params` / `query_params` |
| 依赖 `NilTransport`「成功」 | 真实 `Transport` + 持久化存储 |
| 默认打开 WASM / 支付 / 链适配 | 特性开关 + experimental 标注 |
| 仅用 `v test .` 当 CI 门槛 | 与 GitHub Actions 对齐的按包测试 |
| 密钥进仓或 compose 提交真实密钥 | 环境 / 密钥仓 + 从 `.env.example` 轮换 |
| 巨型无模块 `main` | `core.Module` 生命周期 + 薄入口 |

---

## 上线前清单

- [ ] `/health` 与 `/health/deep` 已接线；deep 覆盖真实依赖
- [ ] 限流与 `max_connections` 符合预期流量
- [ ] JWT 密钥长度 ≥ 16；仓库无密钥
- [ ] SQL 路径使用绑定参数，必要时用事务
- [ ] 需要共识时 Raft 具备 Transport + 持久化
- [ ] `SIGINT`/`SIGTERM` 能干净停机
- [ ] CI 按包测试通过；compose 配置冒烟 OK
- [ ] 实验模块不在默认请求路径上

---

## 相关文档

- [架构](../docs/architecture.zh.md) · [快速开始](../docs/quickstart.zh.md) · [发版说明](../docs/RELEASE.md)
- [模块指南](MODULES_GUIDE.zh.md) · [英文](MODULES_GUIDE.md)
- [部署](../deploy/README.zh.md) · [安全](../SECURITY.zh.md) · [开源清单](../docs/OPEN_SOURCE_CHECKLIST.zh.md)
