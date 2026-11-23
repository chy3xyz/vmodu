# VModu 模块指南

**English (default):** [MODULES_GUIDE.md](MODULES_GUIDE.md)

面向 **V 0.5.2+**、VModu **0.2.0+**。  
状态图例与根 [README](../README.md#module-status) 一致：✅ 可用 · ⚠️ 实验（非默认生产路径）。

生产习惯（环境变量、限流、SQL 参数、Raft 持久化）见 [BEST_PRACTICES.zh.md](BEST_PRACTICES.zh.md)。

---

## 架构

`vmodu/` 下的 Modulith 布局：模块经事件总线与可选意图路由解耦。默认进程入口为 `main.v`（HTTP + health + metrics）。

```
┌─────────────────────────────────────────────────────────────┐
│                        应用层                               │
├──────────────────────────────┬──────────────────────────────┤
│ Agent (planner / tool / llm) │ Intent 路由                  │
├──────────────────────────────┼──────────────────────────────┤
│ Adapters (evm / solana) ⚠️   │ WASM sandbox ⚠️              │
├──────────────────────────────┼──────────────────────────────┤
│ Runtime (actor / supervisor) │ Cluster (raft / node / shard)│
├──────────────────────────────┼──────────────────────────────┤
│ Core (modulith 容器)         │ Event bus                    │
├──────────────────────────────┴──────────────────────────────┤
│ Infra: http · sql · auth · health · metrics · trace · …     │
├─────────────────────────────────────────────────────────────┤
│ Config（VMODU_* 运行时 + 可选 JSON 热加载）                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Core — `vmodu.core` ✅

模块生命周期容器。

```v
import vmodu.core
import vmodu.event.bus

mut container := core.new_container()
container.with_event_bus(bus.default())
container.register('users', my_module)!
container.init()!
container.start()!
container.stop()!
```

| 类型 / API | 作用 |
|------------|------|
| `Module` | `init` / `start` / `stop` |
| `BaseModule` | 可嵌入的名称/版本辅助（`new_base_module`） |
| `Container` | `register`、`get`、`list`、`init`、`start`、`stop` |

---

## 2. Runtime — `vmodu.runtime` ✅

Mailbox Actor + Supervisor。

```v
import vmodu.runtime

mut actor := runtime.new_actor(runtime.ActorConfig{
	id:           'worker-1'
	mailbox_size: 100
})
actor.start(fn (msg runtime.Message) {})
actor.send(runtime.BaseMessage{})
actor.try_send(runtime.BaseMessage{})
actor.stop()
```

| API | 说明 |
|-----|------|
| `new_actor` / `send` / `try_send` / `send_with_timeout` | 有界邮箱 |
| `new_supervisor` / `add_child` / `supervise_actor` | 重启策略 |

优先消息通信，避免跨协程共享 `mut` 映射。见 [最佳实践](BEST_PRACTICES.zh.md#3-actor)。

---

## 3. 事件总线 — `vmodu.event.bus` ✅

发布/订阅，载荷为字节（非旧文档里的 typed `Event`）。

```v
import vmodu.event.bus

mut b := bus.default()
b.subscribe('user.created', fn (msg bus.Message) {
	_ = msg.payload
})!
b.publish('user.created', 'user-1'.bytes())!
```

| API | 说明 |
|-----|------|
| `new_event_bus` / `default` | 配置或默认总线 |
| `subscribe` / `subscribe_wildcard` / `unsubscribe` | 订阅 |
| `publish` / `publish_with_headers` | 发后即忘 |

处理器保持轻量；重活丢给 Actor。

---

## 4. Intent — `vmodu.intent` ✅

命令式路由（`action` + params）。适合 agent/tool 入口；HTTP 应用非必需。

```v
import vmodu.intent

mut i := intent.new_intent('swap')
i.with_param('from_token', 'ETH')
mut router := intent.new_router()
router.register(my_handler)
_ := router.route(i)
```

---

## 5. HTTP — `vmodu.infra.http` ✅

**默认生产路径**（`main.v` 使用）。

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
server.get('/ping', fn (ctx http.Context) !http.Response {
	mut r := http.new_response()
	r.text('pong')
	return r
})
server.start()!
```

| 关注点 | 0.2 行为 |
|--------|----------|
| 连接上限 | `max_connections`；超额 → **503**（`spawn` 前加锁预占槽位） |
| 限流 | 全局 + 可选按 IP；超额 → **429**，计入 `rate_limited_total` |
| 请求 ID | `X-Request-ID` 入/出 |
| 访问日志 | `access_log` / `VMODU_ACCESS_LOG` 开启时 JSON 行 |
| 追踪 | `http.trace_middleware`；`VMODU_TRACE=1\|console` |

另有 `adapter/veb_adapter` ✅（veb 应用，见 `docs/examples/`）。

---

## 6. SQL — `vmodu.infra.db.sql` ✅（按驱动）

```v
import vmodu.infra.db.sql

mut pool := sql.new_pool(sql.Config{
	db_type:         .sqlite
	database:        'app.db'
	max_connections: 4
})!
defer { pool.close() }

pool.exec_params('INSERT INTO items (id, name) VALUES (?, ?)', [id, name])!
rows := pool.query_params('SELECT id, name FROM items WHERE id = ?', [id])!

mut tx := pool.begin()!
tx.exec_params('UPDATE items SET name = ? WHERE id = ?', [name2, id])!
tx.commit()!
```

| API | 用途 |
|-----|------|
| `exec_params` / `query_params` | 绑定参数（`?`；PG 改写 `$n`） |
| `Pool.begin` → `Tx` | 多语句写；务必 `commit` / `rollback` |
| `execute` / `query` | 仅可信 DDL/运维 |
| `Repository[T]` | 简单 CRUD + 标识符校验 |

SQLite 验证最充分；MySQL/PostgreSQL 需本机库与 CI。

---

## 7. 鉴权（JWT）— `vmodu.infra.auth` ✅

```v
import vmodu.infra.auth

mut jwt := auth.new_jwt_manager(auth.JWTConfig{
	secret:     os.getenv('VMODU_JWT_SECRET') // 长度 ≥ auth.min_jwt_secret_len（16）
	issuer:     'myapp'
	access_ttl: 3600
})
token := jwt.generate(user_id, ['user'], ['read'])!
payload := jwt.verify(token)!
```

验签恒定时间比较。空/过短密钥在 `generate` / `verify` 时失败。

---

## 8. Health / metrics / trace ✅

### Health — `vmodu.infra.health`

```v
import vmodu.infra.health

mut checker := health.default_checker()
checker.register('database', fn () health.ComponentHealth {
	return health.ComponentHealth{
		name:    'database'
		status:  .healthy
		message: 'ok'
	}
})!
report := checker.run_checks()
```

默认入口：`/health`（存活）、`/health/deep`（聚合；不健康 → 503）。

### Metrics — `vmodu.infra.metrics`

```v
import vmodu.infra.metrics

mut registry := metrics.new_registry('myapp')
mut c := registry.new_counter('http_requests_total', 'HTTP requests', {})!
c.inc()
text := metrics.new_exporter(registry).export() // Prometheus 文本；挂在 /metrics
```

### Trace — `vmodu.infra.trace`

```v
import vmodu.infra.trace

mut tracer := trace.new_tracer('myapp', trace.new_console_exporter(false))
mut span := tracer.start_span('work', trace.SpanOptions{})
span.set_attribute('key', 'value')
tracer.finish(mut span)
```

导出器：`NoopExporter`、`ConsoleExporter`、`InMemoryExporter`、`BatchExporter`。完整 OTLP 属后续工作。

---

## 9. Raft — `vmodu.cluster.raft` ✅

```v
import vmodu.cluster.raft

mut node := raft.new_node('n1', ['n2', 'n3'])
mut transport := raft.MemoryTransport{}
node.set_transport(mut transport)

mut storage := raft.new_wal_storage_opts('/var/lib/vmodu/raft', .every_write)
node.set_storage(mut storage)
node.load_persistent()!
node.start()
```

| 组件 | 说明 |
|------|------|
| `Transport` | 必需；默认 `NilTransport` 不会假装成功 |
| `FileStorage` | JSON 持久状态 |
| `WalStorage` | 追加 WAL；生产倾向 `WalFsyncMode.every_write` |
| `compact_log` / `install_snapshot` | 控制日志膨胀（非完整流式快照协议） |

`cluster/node`、`cluster/shard` 为更高层集群/分片辅助；多节点运维需自备手册。

---

## 10. Config — `vmodu.config` ✅

**进程环境变量（HTTP 运行时优先）：**

```v
import vmodu.config { load_runtime_config }

rt := load_runtime_config() // VMODU_HTTP_*、VMODU_RATE_*、VMODU_ACCESS_LOG、VMODU_TRACE …
```

完整表见 [docs/quickstart.zh.md](../docs/quickstart.zh.md)。

**可选 JSON + 监视：** `config.new_manager()` — 应用自定义文件配置，不能替代 `VMODU_*`。

---

## 11. Circuit / pool / 其他 infra ✅ / 不等

| 模块 | 状态 | 摘要 |
|------|------|------|
| `infra/circuit` | ✅ | 熔断 |
| `infra/pool` | ✅ | 通用连接池 |
| `infra/logger` | ✅ | 结构化日志 |
| `infra/cache`（Redis） | ✅ | 需 Redis 库 |
| `infra/ws` | 可用 / 演进中 | WebSocket |
| `infra/mq` | ⚠️ | InMemory 可用；Rabbit/Kafka 骨架 |
| `infra/rpc` | ⚠️ | 网关脚手架 |
| `infra/payment` | ⚠️ | 支付骨架 |

---

## 12. Agent — `vmodu.agent.*` ⚠️ / 部分

| 模块 | 说明 |
|------|------|
| `agent/tool` | 工具注册表 |
| `agent/planner` | 任务拆解 |
| `agent/llm` | HTTP LLM 客户端；`decompose` 用 json2 — 仍在演进 |

无鉴权与配额时，勿把 agent/LLM 挂到默认公网路径。

---

## 13. Adapters 与 WASM ⚠️ 实验

| 模块 | 门槛 |
|------|------|
| `adapters/evm`、`adapters/solana` | 骨架 — 仅特性开关 |
| `wasm/sandbox` | 未设 `VVMODU_WASM_SIMULATE=1` 时 `execute` 报错；测试优先 `execute_simulated` |
| `wasm/wasmtime` | 骨架 — 非真实 wasmtime 绑定 |

---

## 依赖规则

1. 上层可依赖下层。
2. 同层尽量经事件总线，少硬引用。
3. 禁止循环依赖。
4. 实验模块未经显式开关不得挂在默认监听上。

---

## 最小应用草图

```v
module main

import vmodu.core { new_container }
import vmodu.config { load_runtime_config }
import vmodu.infra.http
import vmodu.infra.health

fn main() {
	mut container := new_container()
	container.start()!

	rt := load_runtime_config()
	mut checker := health.default_checker()
	_ = checker

	mut server := http.new_server(http.ServerConfig{
		host: rt.http_host
		port: rt.http_port
		access_log: false
	})
	server.get('/health', fn (ctx http.Context) !http.Response {
		mut r := http.new_response()
		r.json({'status': 'ok'})
		return r
	})
	server.start()!
}
```

或直接跑仓库入口：`v run main.v`（已接线 metrics、deep health、限流、SIGINT/SIGTERM）。

---

## 相关文档

- [最佳实践](BEST_PRACTICES.zh.md) · [架构](../docs/architecture.zh.md) · [快速开始](../docs/quickstart.zh.md)
- [API 参考](../docs/api-reference.zh.md) · [发版说明](../docs/RELEASE.md)
- [安全](../SECURITY.zh.md)
