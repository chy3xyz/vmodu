# Chy3 - 创意分享与 AI 打磨系统

Creative Hub with AI Polish (chy3) - 基于 VModulith Runtime 的创意平台示例

## 功能特性

- ✅ 用户创意提交和验证
- ✅ AI 自动打磨和优化
- ✅ 创意评分和标签生成
- ✅ 实时事件通知
- ✅ 指标收集和健康检查
- ✅ 异步处理，高并发支持

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interface                         │
│                    (HTTP / CLI / Web)                       │
└──────────────┬──────────────────────────────────────────────┘
               │ Intent (submit_idea, get_ideas)
┌──────────────▼──────────────────────────────────────────────┐
│                   Intent Router                             │
│              统一入口，路由分发                              │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│                   Idea Service                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Validation  │→ │ Store       │→ │ Publish Event       │ │
│  │ (validate)  │  │ (save)      │  │ (idea.created)      │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└──────────────┬──────────────────────────────────────────────┘
               │ EventBus (idea.created)
┌──────────────▼──────────────────────────────────────────────┐
│                    AI Processor                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ LLM Call    │→ │ Parse       │→ │ Publish Event       │ │
│  │ (polish)    │  │ (result)    │  │ (idea.polished)     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└──────────────┬──────────────────────────────────────────────┘
               │ EventBus (idea.polished)
┌──────────────▼──────────────────────────────────────────────┐
│              Notification Service                           │
│              (notify subscribers)                           │
└─────────────────────────────────────────────────────────────┘
```

## 快速开始

### 1. 编译运行

```bash
# 进入项目目录
cd /Users/n0x/ws_clawworld/vmodu_runtime

# 编译示例
v -enable-globals docs/examples/chy3.v -o chy3

# 运行
./chy3
```

### 2. 预期输出

```
╔════════════════════════════════════════════════════════════╗
║      Chy3 - 创意分享与 AI 打磨系统                         ║
║      Creative Hub with AI Polish                          ║
╚════════════════════════════════════════════════════════════╝

[系统] 事件总线已启动
[系统] LLM 客户端已初始化
[系统] 创意服务已启动
[系统] 通知服务已启动
...

═════════════════════════════════════════════════════════════
                        创意列表                             
═════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────┐
│ 📌 AI 智能园丁
├──────────────────────────────────────────────────────────┤
│ 作者: 张三
│ 状态: completed
│ 内容: 开发一个能自动识别植物病害...
│
│ 🤖 AI 打磨结果:
│ 评分: 85.5/100 ⭐
│ 标签: 创新, 创业, AI, 创意
│ 优化内容: 【优化版】...
└──────────────────────────────────────────────────────────┘
```

## 核心组件说明

### 1. IntentRouter - 意图路由

统一入口点，将用户请求路由到对应处理器：

```v
mut router := new_intent_router(event_bus)

// 注册处理器
router.register('submit_idea', fn (intent Intent) !string {
    // 处理创意提交
    return '{"status": "ok", "id": "idea_123"}'
})

// 路由请求
result := router.route(Intent{
    action: 'submit_idea'
    payload: '{"title": "...", "content": "..."}'
})!
```

### 2. IdeaService - 创意服务

核心业务逻辑：

```v
mut service := new_idea_service(event_bus, llm_client)

// 提交创意
idea := service.submit_idea(
    title: 'AI 智能园丁'
    content: '开发一个能自动识别植物病害的...'
    author: '张三'
)!

// 获取创意列表
ideas := service.get_ideas()
```

### 3. EventBus - 事件总线

模块间通信：

```v
// 订阅事件
event_bus.subscribe('idea.created', fn (msg Message) {
    println('新创意: ${msg.payload}')
})!

// 发布事件
event_bus.publish('idea.created', json.encode(event).bytes())!
```

### 4. AI 打磨流程

```
用户提交创意
    ↓
验证格式和内容
    ↓
存储创意（status: pending）
    ↓
发布 idea.created 事件
    ↓
AI Processor 接收事件
    ↓
调用 LLM 进行打磨
    ↓
解析结果（优化内容、评分、标签）
    ↓
更新创意（status: completed）
    ↓
发布 idea.polished 事件
    ↓
通知订阅者
```

## API 参考

### 数据结构

```v
// 创意结构
struct Idea {
    id          string
    title       string
    content     string
    author      string
    created_at  i64
    status      IdeaStatus    // pending, polishing, completed, rejected
    polished    string        // AI 优化后的内容
    score       f64           // AI 评分
    tags        []string      // AI 生成的标签
}

// 意图结构
struct Intent {
    action      string   // submit_idea, get_ideas, share_idea
    payload     string   // JSON 数据
    user_id     string
    request_id  string
}

// 事件结构
struct IdeaEvent {
    action     string   // created, polished, shared
    idea       Idea
    timestamp  i64
}
```

### 方法列表

| 方法 | 说明 |
|------|------|
| `IdeaService.submit_idea()` | 提交新创意 |
| `IdeaService.get_ideas()` | 获取创意列表 |
| `IdeaService.get_idea(id)` | 获取单个创意 |
| `NotificationService.subscribe()` | 订阅创意更新 |
| `IntentRouter.register()` | 注册意图处理器 |
| `IntentRouter.route()` | 路由意图 |

## 扩展建议

### 1. 接入真实 LLM

将 `simulate_llm_response()` 替换为真实调用：

```v
fn (mut s IdeaService) polish_idea_with_llm(idea_id string) {
    // ...
    response := s.llm_client.complete(prompt) or {
        eprintln('LLM 调用失败: ${err}')
        return
    }
    
    // 解析 OpenAI/Anthropic 响应
    result := parse_llm_response(response)
    // ...
}
```

### 2. 添加 HTTP API

使用 V 的 `veb` 框架暴露 REST API：

```v
import veb

pub struct App {
    veb.Controller
    idea_service &IdeaService
}

@['/api/ideas'; post]
pub fn (mut app App) submit_idea(mut ctx Context) veb.Result {
    idea := app.idea_service.submit_idea(
        ctx.form['title'],
        ctx.form['content'],
        ctx.form['author']
    ) or {
        return ctx.json('{"error": "${err}"}')
    }
    return ctx.json(json.encode(idea))
}
```

### 3. 添加持久化存储

使用 `vmodu/infra/db` 替换内存存储：

```v
pub struct IdeaService {
pub mut:
    store &event_store.PersistentLog  // 替换 map[string]Idea
    // ...
}
```

### 4. 添加 WebSocket 实时通知

```v
// WebSocket 处理器
pub fn ws_handler(mut conn ws.Conn, msg ws.Message) {
    // 订阅 idea.polished 事件
    event_bus.subscribe('idea.polished', fn [mut conn] (msg Message) {
        conn.write(msg.payload, .text_frame) or {}
    })!
}
```

### 5. 添加用户认证

```v
pub fn (mut s IdeaService) submit_idea(
    title string, 
    content string, 
    author string,
    token string  // JWT token
) !Idea {
    // 验证 token
    user := auth.validate_token(token) or {
        return error('未授权')
    }
    // ...
}
```

## 性能优化

1. **连接池**：LLM 客户端使用连接池
2. **批量处理**：创意批量提交和打磨
3. **缓存**：热点创意缓存
4. **限流**：AI 打磨限流（避免 API 配额耗尽）

## 监控指标

| 指标 | 说明 |
|------|------|
| `chy3_ideas_submitted_total` | 提交的创意总数 |
| `chy3_ideas_polished_total` | 完成打磨的创意数 |
| `chy3_avg_score` | 平均创意评分 |
| `chy3_polish_duration_ms` | AI 打磨耗时 |

## 相关文档

- [VModulith Runtime 架构](../../docs/architecture.md)
- [Actor 模型](../../docs/examples/01-hello-actors.v)
- [事件总线](../../docs/examples/02-event-bus.v)
- [Intent Router](../../docs/examples/03-intent-router.v)

## 许可证

MIT
