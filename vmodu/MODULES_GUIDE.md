# VModulith Modules 功能说明与使用指南

## 架构概览

VModulith Runtime 采用**模块化单体(Modulith)**架构，所有模块位于 `vmodu/` 目录下，通过事件总线和意图系统进行松耦合通信。

```
┌─────────────────────────────────────────────────────────────┐
│                        应用层 (App)                          │
├─────────────────────────────────────────────────────────────┤
│  Agent ( planner + tool + llm )    │    Intent/Router       │
├─────────────────────────────────────────────────────────────┤
│  Adapters ( evm + solana )         │    WASM ( sandbox )    │
├─────────────────────────────────────────────────────────────┤
│  Runtime ( actor )                 │    Cluster (node/shard)│
├─────────────────────────────────────────────────────────────┤
│  Core ( modulith )                 │    Event Bus           │
├─────────────────────────────────────────────────────────────┤
│  Infra Layer (health/metrics/circuit/db/pool/rpc/ws/trace)  │
├─────────────────────────────────────────────────────────────┤
│  Config                                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Core 层 - 框架核心

### core/modulith - 模块化单体框架
**功能**：模块生命周期管理、依赖注入、启动/停止协调

```v
import vmodu.core { Container, Module, new_container }

// 创建容器
mut container := new_container()

// 注册模块
container.register('my_module', my_module)!

// 启动所有模块
container.start()!

// 停止所有模块
container.stop()!
```

**核心概念**：
- `Module` 接口：所有业务模块必须实现
- `Container`：模块注册表和生命周期管理器
- `BaseModule`：可嵌入的基础模块结构

---

## 2. Runtime 层 - 运行时基础

### runtime/actor - Actor 运行时
**功能**：基于 Mailbox 的并发消息处理

```v
import vmodu.runtime { new_actor, ActorConfig }

// 创建 Actor
mut actor := new_actor(ActorConfig{
    id: 'worker-1'
    mailbox_size: 100
})

// 启动消息处理
actor.start(fn (msg Message) {
    // 处理消息
})

// 发送消息
actor.send(msg)

// 非阻塞发送
if actor.try_send(msg) {
    // 发送成功
}
```

**核心概念**：
- `Actor`：轻量级执行单元
- `Message`：消息接口
- `Mailbox`：有界消息队列

---

## 3. Event 层 - 事件通信

### event/bus - 事件总线
**功能**：发布/订阅模式的事件通信

```v
import vmodu.event.bus { default }

// 获取默认事件总线
mut bus := bus.default()

// 订阅事件
bus.subscribe('user.created', fn (event Event) {
    println('User created: ${event.data}')
})

// 发布事件
bus.publish(Event{
    topic: 'user.created'
    data:  user_data
})
```

**核心概念**：
- `EventBus`：事件路由中心
- `Event`：事件数据结构
- `Subscription`：订阅句柄

---

## 4. Intent 层 - 意图路由

### intent/intent - 意图系统
**功能**：命令模式 + 路由，统一入口处理

```v
import vmodu.intent { new_intent, new_router }

// 创建意图
mut i := new_intent('swap')
i.with_param('from_token', 'ETH')
i.with_param('to_token', 'USDC')
i.with_param('amount', '1.5')

// 创建路由器
mut router := new_router()

// 注册处理器
router.register(MyHandler{})

// 路由意图
result := router.route(i)
```

**核心概念**：
- `Intent`：包含 action 和 params 的意图对象
- `IntentHandler`：意图处理器接口
- `Router`：意图路由器

---

## 5. Cluster 层 - 分布式集群

### cluster/node - 集群节点
**功能**：分布式 Actor 集群管理

```v
import vmodu.cluster.node { new_cluster, new_node }

// 创建集群节点
mut cluster := new_cluster('node-1', '0.0.0.0', 9000)

// 启动集群
cluster.start()!

// 加入现有集群
cluster.join('seed.node.com', 9000)!

// 注册本地 Actor
cluster.add_local_actor('actor-1')

// 发送消息到 Actor（自动路由到正确节点）
cluster.send_message('actor-1', msg)!
```

### cluster/shard - 一致性哈希分片
**功能**：Actor 分布和负载均衡

```v
import vmodu.cluster.shard { new_shard_manager }

// 创建分片管理器
mut sharder := new_shard_manager(3) // 复制因子为3

// 添加节点
sharder.add_node('node-1')
sharder.add_node('node-2')
sharder.add_node('node-3')

// 获取 Actor 位置
location := sharder.get_actor_location('actor-1')
println('Primary: ${location.primary}')
println('Replicas: ${location.replicas}')
```

---

## 6. Agent 层 - AI 智能体

### agent/tool - 工具系统
**功能**：Agent 可调用工具的接口和注册

```v
import vmodu.agent.tool { new_registry, Tool }

// 创建工具注册表
mut registry := new_registry()

// 注册工具
registry.register(EchoTool{})
registry.register(CalculatorTool{})

// 获取工具
if tool := registry.get('echo') {
    result := tool.run('hello')
}

// 列出所有工具
tools := registry.list()
```

### agent/planner - 任务规划器
**功能**：将复杂任务分解为可执行步骤

```v
import vmodu.agent.planner { new_planner, Task }

// 创建规划器
mut planner := new_planner()

// 注册可用工具
planner.register_tool(echo_tool)

// 创建任务
task := Task{
    id: 'task-1'
    description: 'Swap 100 USDC for ETH'
}

// 生成执行计划
plan := planner.create_plan(task)

// 格式化输出
println(format_plan(plan))
```

### agent/llm - LLM 客户端
**功能**：大语言模型 API 调用封装

```v
import vmodu.agent.llm { new_client }

// 创建 LLM 客户端
mut client := new_client('openai', 'gpt-4')

// 配置 API 密钥
client.set_api_key('sk-...')

// 发送请求
response := client.complete('Hello, how are you?')!

// 流式响应
client.complete_stream('Tell me a story', fn (chunk string) {
    print(chunk)
})!
```

---

## 7. Adapters 层 - 区块链适配

### adapters/evm - EVM 适配器
**功能**：以太坊及兼容链交互

```v
import vmodu.adapters.evm { new_adapter, Transaction }

// 创建适配器
mut evm := new_adapter('https://eth-mainnet.g.alchemy.com/v2/...')

// 连接
evm.connect()!

// 获取余额
balance := evm.get_balance('0x...')

// 发送交易
tx := Transaction{
    from: '0x...'
    to: '0x...'
    value: '1000000000000000000' // 1 ETH
    gas_limit: 21000
}
tx_hash := evm.send_transaction(tx)!

// 调用合约
result := evm.call(contract_addr, call_data)
```

### adapters/solana - Solana 适配器
**功能**：Solana 区块链交互

```v
import vmodu.adapters.solana { new_adapter }

// 创建适配器
mut sol := new_adapter('https://api.devnet.solana.com')

// 连接
sol.connect()!

// 获取 SOL 余额
lamports := sol.get_balance('HN7c...')
sol_amount := lamports_to_sol(lamports)

// 获取 Token 账户
token_accounts := sol.get_token_accounts('HN7c...')
```

---

## 8. Infra 层 - 基础设施

### infra/health - 健康检查
**功能**：服务健康状态监控

```v
import vmodu.infra.health { new_checker }

mut checker := new_checker()

// 注册组件
checker.register('database', fn () HealthStatus {
    if db.is_connected() {
        return .healthy
    }
    return .unhealthy
})

// 执行检查
report := checker.check_all()
```

### infra/metrics - 指标收集
**功能**：Prometheus 风格指标

```v
import vmodu.infra.metrics { new_counter, new_histogram }

// 计数器
mut requests := new_counter('http_requests_total')
requests.inc()
requests.inc_by(5)

// 直方图
mut latency := new_histogram('request_duration_seconds')
latency.observe(0.23)
```

### infra/circuit - 熔断器
**功能**：故障保护和自动恢复

```v
import vmodu.infra.circuit { new_breaker }

mut cb := new_breaker('api_service', BreakerConfig{
    failure_threshold: 5
    timeout: 30 * time.second
})

// 执行受保护调用
result := cb.execute(fn () !string {
    return http_get('https://api.example.com')
})!
```

### infra/pool - 连接池
**功能**：通用连接池管理

```v
import vmodu.infra.pool { new_pool }

mut pool := new_pool(PoolConfig{
    max_size: 10
    min_idle: 2
})

// 获取连接
conn := pool.acquire()!
defer { pool.release(conn) }

// 使用连接
conn.execute('SELECT * FROM users')
```

### infra/db - 数据库
**功能**：数据库访问和事件存储

```v
import vmodu.infra.db { new_event_store }

mut store := new_event_store()

// 存储事件
store.append(Event{
    aggregate_id: 'order-1'
    event_type: 'OrderCreated'
    data: order_data
})!

// 读取事件流
events := store.read_stream('order-1')!
```

### infra/rpc - RPC 网关
**功能**：外部 API 访问入口

```v
import vmodu.infra.rpc { new_gateway }

mut gateway := new_gateway()

// 注册处理器
gateway.register_handler('swap', swap_handler)
gateway.register_handler('transfer', transfer_handler)

// 添加中间件
gateway.add_middleware(auth_middleware)
gateway.add_middleware(logging_middleware)

// 启动
gateway.start()!
```

### infra/ws - WebSocket
**功能**：实时双向通信

```v
import vmodu.infra.ws { new_server }

mut server := new_server(8080)

// 设置回调
server.set_on_connect(fn (client Client) {
    println('Client ${client.id} connected')
})

// 广播消息
server.broadcast('updates', {'msg': 'Hello all'})

// 启动
server.start()!
```

### infra/logger - 日志
**功能**：结构化日志

```v
import vmodu.infra.logger { info, error, debug }

info('Application started')
debug('Config loaded: ${config}')
error('Failed to connect: ${err}')
```

### infra/trace - 分布式追踪
**功能**：请求链路追踪

```v
import vmodu.infra.trace { start_span }

mut span := start_span('process_order')
defer { span.finish() }

span.add_tag('order_id', order_id)
span.log('Processing payment')
```

---

## 9. WASM 层 - 沙箱执行

### wasm/sandbox - WASM 沙箱
**功能**：安全执行 WASM 模块

```v
import vmodu.wasm.sandbox { new_sandbox }

// 创建沙箱
mut sandbox := new_sandbox()

// 设置资源限制
sandbox.with_limits(32 * 1024 * 1024, 10000) // 32MB, 10s

// 加载 WASM 模块
wasm_code := os.read_file('tool.wasm')!
sandbox.load_module('calculator', wasm_code)!

// 执行函数
result := sandbox.execute('calculator', 'add', '1,2')
if result.success {
    println('Result: ${result.output}')
}
```

---

## 10. Config 层 - 配置管理

### config/config - 配置系统
**功能**：多源配置加载和管理

```v
import vmodu.config { new_loader }

mut loader := new_loader()

// 从文件加载
loader.load_file('config.json')!

// 从环境变量加载
loader.load_env('VMODU_')

// 获取配置值
port := loader.get_int('server.port')
db_url := loader.get_string('database.url')
```

---

## 模块依赖关系图

```
config (基础层)
    ↑
core ←→ event/bus ←→ intent (核心层)
    ↑       ↑
runtime ←→ cluster (运行时层)
    ↑
agent ←→ adapters (业务层)
    ↑
infra/* (基础设施层)
```

**依赖原则**：
1. 上层可以依赖下层
2. 同层模块通过事件总线通信
3. 禁止循环依赖

---

## 快速开始模板

```v
module main

import vmodu.core { new_container }
import vmodu.event.bus { default }
import vmodu.infra.health { new_checker }

fn main() {
    // 1. 创建容器
    mut container := new_container()
    
    // 2. 注册模块
    container.register('health', new_checker())!
    
    // 3. 启动系统
    container.start()!
    
    // 4. 运行业务逻辑
    
    // 5. 优雅关闭
    container.stop()!
}
```
