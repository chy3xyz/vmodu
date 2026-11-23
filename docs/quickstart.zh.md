# 快速开始

**English (default):** [quickstart.md](quickstart.md)

## 前置要求

- **V 0.5.2+**（[源码安装](https://github.com/vlang/v#installing-v-from-source)）
- 可选：Docker（见 `deploy/`）

```bash
v version   # 期望 V 0.5.2 或更新
```

## 克隆与运行

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu

# 开发
v run main.v

# 或生产二进制
v -prod -o vmodu main.v
./vmodu
```

默认监听 `0.0.0.0:8080`。可用环境变量覆盖（见 `vmodu/config/runtime.v`）：

| 变量 | 默认 | 含义 |
|------|------|------|
| `VMODU_HTTP_HOST` | `0.0.0.0` | 绑定地址 |
| `VMODU_HTTP_PORT` | `8080` | 监听端口 |
| `VMODU_MAX_CONNECTIONS` | `1024` | 最大并发连接 |
| `VMODU_RATE_LIMIT_RPS` | `1000` | 全局限流（req/s） |
| `VMODU_RATE_LIMIT_BURST` | `200` | 全局突发 |
| `VMODU_IP_RATE_LIMIT_RPS` | `100` | 按 IP 限流 |
| `VMODU_IP_RATE_LIMIT_BURST` | `50` | 按 IP 突发 |
| `VMODU_RATE_LIMIT_PER_IP` | `true` | 启用按 IP 桶（`1`/`0`/`true`/`false`） |
| `VMODU_ACCESS_LOG` | `true` | JSON 访问日志 |
| `VMODU_TRACE` | `false` | `true`/`console` → 控制台 span 导出 |

```bash
VMODU_HTTP_PORT=9090 v run main.v

curl -s http://127.0.0.1:8080/health
# {"status":"ok"}

curl -s http://127.0.0.1:8080/health/deep
# 组件聚合 JSON

curl -sD - http://127.0.0.1:8080/health -H 'X-Request-ID: demo' | head
# 响应含 X-Request-ID

curl -s http://127.0.0.1:8080/metrics | head
```

Compose 配置冒烟（Docker 可选）：

```bash
bash deploy/scripts/compose-smoke.sh
```

> 默认 `main.v` 使用本地 metrics 注册表——通常**不需要** `-enable-globals`。

## Docker（可选）

```bash
cd deploy
cp .env.example .env   # 轮换密钥
docker compose up -d
```

见 [deploy/README.zh.md](../deploy/README.zh.md)。除非 compose 写明，否则不要假设 Grafana `admin/admin`。

## 脚手架

```bash
cd cmd/vmodu-cli
v run . new myapp
cd ../../myapp   # 或以 CLI 打印路径为准
v run main.v
```

## 推荐测试（贡献前）

整树 `v test .` 可能因多入口 / 可选依赖失败。优先：

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
v test vmodu/adapter/veb_adapter
```

## 下一步

- [架构](architecture.zh.md)
- [API 参考](api-reference.zh.md)
- [模块状态表](../README.zh.md)
- [最佳实践](../vmodu/BEST_PRACTICES.zh.md)
- [贡献](../CONTRIBUTING.zh.md)
