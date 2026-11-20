# VModulith Runtime 最佳实践指南

## 1. 项目结构最佳实践

### 推荐目录结构

```
my_project/
├── v.mod                      # V 模块定义
├── main.v                     # 应用入口
├── config/
│   └── config.json            # 配置文件
├── src/
│   ├── modules/               # 业务模块
│   │   ├── user/
│   │   │   ├── user.v         # 模块定义
│   │   │   ├── user_test.v    # 单元测试
│   │   │   └── handler.v      # 事件处理器
│   │   └── order/
│   ├── services/              # 服务层
│   └── models/                # 数据模型
└── docs/
```

### v.mod 模板

```v
Module {
    name: 'my_project'
    description: 'My VModulith Application'
    version: '0.1.0'
    license: 'MIT'
    dependencies: [
        'vmodu'
    ]
}
```

---

## 2. 模块开发最佳实践

### Module 接口实现

```v
// 推荐：完整实现 Module 接口
module user

import vmodu.event.bus
import vmodu.core

pub struct UserModule {
    core.BaseModule
mut:
    users map[string]User
    bus   &bus.EventBus
}

// 必须实现 Module 接口的方法
pub fn (mut m UserModule) init(event_bus &bus.EventBus) ! {
    m.bus = event_bus
    // 订阅相关事件
    m.bus.subscribe('user.register', m.on_user_register)
}

pub fn (mut m UserModule) start() ! {
    // 启动模块服务
}

pub fn (mut m UserModule) stop() ! {
    // 清理资源
    m.users.clear()
}

// 业务方法
pub fn (mut m UserModule) create_user(name string, email string) !User {
    user := User{
        id: generate_id()
        name: name
        email: email
    }
    m.users[user.id] = user
    
    // 发布事件
    m.bus.publish(bus.Event{
        topic: 'user.created'
        data: user
    })
    
    return user
}

fn (mut m UserModule) on_user_register(event bus.Event) {
    // 处理事件
}
```

### 错误处理最佳实践

```v
// 推荐：使用 Result 类型和错误传播
pub fn (mut s Service) process_order(order_id string) !Order {
    // 验证订单
    order := s.find_order(order_id) or {
        return error('Order not found: ${order_id}')
    }
    
    // 检查库存
    s.check_inventory(order) or {
        return error('Inventory check failed: ${err}')
    }
    
    // 处理支付
    s.process_payment(order)!
    
    return order
}

// 调用方处理
fn main() {
    order := service.process_order('123') or {
        println('Failed to process: ${err}')
        return
    }
    println('Order processed: ${order.id}')
}
```

---

## 3. Actor 并发最佳实践

### Actor 设计原则

```v
// 推荐：每个 Actor 负责单一职责
module order_actor

import vmodu.runtime

// 定义消息类型
pub struct CreateOrderMsg {
    runtime.BaseMessage
    user_id string
    items   []Item
}

pub struct OrderActor {
    id string
mut:
    orders map[string]Order
}

// 创建 Actor
pub fn new_order_actor(id string) &runtime.Actor {
    mut actor := runtime.new_actor(runtime.ActorConfig{
        id: id
        mailbox_size: 1000
    })
    
    actor.start(fn (msg runtime.Message) {
        match msg {
            CreateOrderMsg {
                handle_create_order(msg)
            }
            CancelOrderMsg {
                handle_cancel_order(msg)
            }
            else {
                println('Unknown message type')
            }
        }
    })
    
    return actor
}
```

### 避免共享状态

```v
// 不推荐：共享可变状态
mut shared_data := map[string]int{}

spawn fn [mut shared_data] () {
    shared_data['key'] = 1  // 数据竞争！
}()

// 推荐：通过消息传递
actor.send(UpdateMsg{key: 'key', value: 1})
```

---

## 4. 事件驱动架构最佳实践

### 事件定义

```v
// events.v - 集中定义所有事件
module events

import vmodu.event.bus

// 用户事件
pub struct UserCreatedEvent {
    user_id string
    email   string
}

pub struct UserDeletedEvent {
    user_id string
}

// 订单事件
pub struct OrderPlacedEvent {
    order_id string
    user_id  string
    amount   f64
}

// 事件发布辅助函数
pub fn publish_user_created(mut bus bus.EventBus, user User) {
    bus.publish(bus.Event{
        topic: 'user.created'
        data:  UserCreatedEvent{
            user_id: user.id
            email:   user.email
        }
    })
}
```

### 事件订阅模式

```v
// 推荐：按业务域组织事件处理器
module notification_service

import vmodu.event.bus

pub struct NotificationService {
mut:
    bus &bus.EventBus
}

pub fn (mut s NotificationService) subscribe_events() {
    // 用户事件
    s.bus.subscribe('user.created', s.on_user_created)
    s.bus.subscribe('user.deleted', s.on_user_deleted)
    
    // 订单事件
    s.bus.subscribe('order.placed', s.on_order_placed)
    s.bus.subscribe('order.completed', s.on_order_completed)
}

fn (s &NotificationService) on_user_created(event bus.Event) {
    // 发送欢迎邮件
}

fn (s &NotificationService) on_order_placed(event bus.Event) {
    // 发送订单确认
}
```

---

## 5. 区块链集成最佳实践

### 多链支持模式

```v
// blockchain/client.v
module blockchain

import vmodu.adapters.evm
import vmodu.adapters.solana

// 统一接口
pub interface ChainClient {
    get_balance(address string) string
    send_transaction(tx Transaction) !string
    is_connected() bool
}

// EVM 客户端包装
pub struct EvmClient {
    adapter evm.EvmAdapter
}

pub fn (c &EvmClient) get_balance(address string) string {
    return c.adapter.get_balance(address)
}

// Solana 客户端包装
pub struct SolanaClient {
    adapter solana.SolanaAdapter
}

pub fn (c &SolanaClient) get_balance(address string) string {
    lamports := c.adapter.get_balance(address)
    return solana.lamports_to_sol(lamports).str()
}

// 工厂函数
pub fn new_client(chain_type string, rpc_url string) !ChainClient {
    match chain_type {
        'ethereum', 'polygon', 'bsc' {
            return EvmClient{evm.new_adapter(rpc_url)}
        }
        'solana' {
            return SolanaClient{solana.new_adapter(rpc_url)}
        }
        else {
            return error('Unsupported chain: ${chain_type}')
        }
    }
}
```

### 交易重试机制

```v
import vmodu.infra.circuit

pub fn send_with_retry(cb &circuit.CircuitBreaker, tx Transaction) !string {
    mut attempts := 0
    max_attempts := 3
    
    for attempts < max_attempts {
        attempts++
        
        result := cb.execute(fn [tx] () !string {
            return adapter.send_transaction(tx)
        }) or {
            if attempts >= max_attempts {
                return error('Max retry exceeded: ${err}')
            }
            // 指数退避
            time.sleep(time.second * attempts)
            continue
        }
        
        return result
    }
    
    return error('Should not reach here')
}
```

---

## 6. Agent AI 集成最佳实践

### Tool 开发规范

```v
// tools/calculator_tool.v
module tools

import vmodu.agent.tool
import json

// 定义输入输出结构
pub struct CalculatorInput {
    operation string // add, subtract, multiply, divide
    a         f64
    b         f64
}

pub struct CalculatorOutput {
    result f64
    error  ?string
}

// 实现 Tool 接口
pub struct CalculatorTool {
    tool.BaseTool
}

pub fn new_calculator_tool() CalculatorTool {
    return CalculatorTool{
        BaseTool: tool.BaseTool{
            tool_name:        'calculator'
            tool_description: 'Perform basic arithmetic operations'
        }
    }
}

pub fn (t &CalculatorTool) run(input string) string {
    // 解析输入
    req := json.decode(CalculatorInput, input) or {
        return json.encode(CalculatorOutput{
            error: 'Invalid input: ${err}'
        })
    }
    
    // 执行计算
    mut result := f64(0)
    match req.operation {
        'add'      { result = req.a + req.b }
        'subtract' { result = req.a - req.b }
        'multiply' { result = req.a * req.b }
        'divide'   { 
            if req.b == 0 {
                return json.encode(CalculatorOutput{
                    error: 'Division by zero'
                })
            }
            result = req.a / req.b 
        }
        else {
            return json.encode(CalculatorOutput{
                error: 'Unknown operation: ${req.operation}'
            })
        }
    }
    
    // 返回结果
    return json.encode(CalculatorOutput{
        result: result
    })
}
```

### Agent 配置模式

```v
// agent/setup.v
module agent

import vmodu.agent.planner
import vmodu.agent.tool

pub fn setup_agent() planner.Planner {
    mut planner := planner.new_planner()
    
    // 注册工具
    planner.register_tool(tools.new_calculator_tool())
    planner.register_tool(tools.new_web_search_tool())
    planner.register_tool(tools.new_blockchain_tool())
    
    // 配置 LLM
    planner.set_llm_config(planner.LlmConfig{
        model:       'gpt-4'
        temperature: 0.7
        max_tokens:  2000
    })
    
    return planner
}
```

---

## 7. 测试最佳实践

### 单元测试模板

```v
// user_test.v
module user

fn test_create_user() {
    mut module := new_user_module()
    module.init(bus.default())!
    
    user := module.create_user('John', 'john@example.com')!
    
    assert user.name == 'John'
    assert user.email == 'john@example.com'
    assert user.id != ''
}

fn test_create_user_duplicate_email() {
    mut module := new_user_module()
    module.init(bus.default())!
    
    module.create_user('John', 'john@example.com')!
    
    // 应该失败
    module.create_user('Jane', 'john@example.com') or {
        assert err.msg().contains('duplicate')
        return
    }
    assert false, 'Should have failed'
}
```

### 集成测试

```v
// integration_test.v
module main

import vmodu.core

fn test_full_workflow() {
    // 创建容器
    mut container := core.new_container()
    
    // 注册所有模块
    container.register('user', user.new_module())!
    container.register('order', order.new_module())!
    container.register('payment', payment.new_module())!
    
    // 启动
    container.start()!
    
    // 执行业务流程
    mut user_mod := container.get('user')! as user.UserModule
    user := user_mod.create_user('Test', 'test@test.com')!
    
    // 验证
    assert user.id != ''
    
    // 清理
    container.stop()!
}
```

---

## 8. 性能优化最佳实践

### 连接池配置

```v
import vmodu.infra.pool

pub fn create_optimized_pool() pool.Pool {
    return pool.new_pool(pool.PoolConfig{
        max_size:        20
        min_idle:        5
        max_lifetime:    30 * time.minute
        idle_timeout:    10 * time.minute
        health_check_interval: 1 * time.minute
    })
}
```

### Actor 池化

```v
// 推荐：Actor 池模式
pub struct ActorPool {
    actors []&runtime.Actor
    index  int
}

pub fn (mut p ActorPool) next() &runtime.Actor {
    actor := p.actors[p.index]
    p.index = (p.index + 1) % p.actors.len
    return actor
}

// 使用
mut pool := ActorPool{
    actors: [
        new_worker_actor('worker-1'),
        new_worker_actor('worker-2'),
        new_worker_actor('worker-3'),
    ]
}

pool.next().send(msg)
```

---

## 9. 安全配置最佳实践

### WASM 沙箱限制

```v
import vmodu.wasm.sandbox

pub fn create_secure_sandbox() sandbox.WasmSandbox {
    mut s := sandbox.new_sandbox()
    
    // 严格资源限制
    s.with_limits(
        memory: 16 * 1024 * 1024,  // 16MB
        cpu_ms: 5000                 // 5秒
    )
    
    return s
}
```

### API 密钥管理

```v
import os
import vmodu.config

pub fn load_secrets() config.Config {
    mut loader := config.new_loader()
    
    // 优先从环境变量加载
    loader.load_env('VMODU_')
    
    // 本地开发时从文件加载
    if os.exists('.env.local') {
        loader.load_file('.env.local')!
    }
    
    return loader
}

// 使用
config := load_secrets()
api_key := config.get_string('api_key') // 从 VMODU_API_KEY 环境变量
```

---

## 10. 监控和可观测性

### 健康检查端点

```v
import vmodu.infra.health
import vmodu.infra.ws

pub fn setup_health_checks() health.Checker {
    mut checker := health.new_checker()
    
    // 数据库健康检查
    checker.register('database', fn () health.Status {
        if db.ping() {
            return .healthy
        }
        return .unhealthy
    })
    
    // 区块链连接检查
    checker.register('blockchain', fn () health.Status {
        if evm_adapter.is_connected() {
            return .healthy
        }
        return .unhealthy
    })
    
    return checker
}
```

### 指标收集

```v
import vmodu.infra.metrics

// 定义指标
mut request_counter := metrics.new_counter('app_requests_total', ['method', 'path'])
mut request_latency := metrics.new_histogram('app_request_duration_seconds', ['method'])

// 使用
fn handle_request(req Request) Response {
    start := time.now()
    
    request_counter.inc(labels: {'method': req.method, 'path': req.path})
    
    response := process(req)
    
    duration := time.since(start).seconds()
    request_latency.observe(duration, labels: {'method': req.method})
    
    return response
}
```

---

## 总结

遵循这些最佳实践可以确保你的 VModulith 应用：

1. **模块化**：清晰的模块边界和依赖关系
2. **可测试**：易于编写单元测试和集成测试
3. **可扩展**：通过 Actor 和事件驱动实现水平扩展
4. **可靠**：熔断器、重试、健康检查保障稳定性
5. **安全**：WASM 沙箱、资源限制保护系统
