# Chy3 快速上手指南

## 5 分钟运行创意分享系统

### 1. 编译运行

```bash
cd /Users/n0x/ws_clawworld/vmodu_runtime

# 直接运行
v -enable-globals run docs/examples/chy3.v

# 或编译为可执行文件
v -enable-globals docs/examples/chy3.v -o chy3
./chy3
```

### 2. 系统架构

```
用户提交创意 → IdeaService → EventBus → AI 打磨 → 通知订阅者
```

### 3. 核心代码解读

#### 3.1 提交创意
```v
mut service := new_idea_service(mut event_bus)

idea := service.submit_idea(
    title:   'AI 智能园丁'
    content: '开发一个能自动识别植物病害的 AI 应用...'
    author:  '张三'
)!
```

#### 3.2 订阅事件
```v
// 当创意被创建时，自动触发 AI 打磨
event_bus.subscribe('idea.created', fn (msg Message) {
    // 调用 AI 处理
})

// 当打磨完成时，发送通知
event_bus.subscribe('idea.polished', fn (msg Message) {
    // 通知用户
})
```

#### 3.3 创意数据结构
```v
struct Idea {
    id          string
    title       string
    content     string
    author      string
    status      IdeaStatus  // pending / polishing / completed
    polished    string      // AI 优化后的内容
    score       f64         // AI 评分
    tags        []string    // AI 标签
}
```

### 4. 扩展功能

#### 添加 HTTP API
```v
import veb

@['/api/ideas'; post]
pub fn (mut app App) submit(mut ctx Context) veb.Result {
    idea := app.service.submit_idea(
        ctx.form['title'],
        ctx.form['content'],
        ctx.form['author']
    ) or { return ctx.json('{"error":"${err}"}') }
    
    return ctx.json(json.encode(idea))
}
```

#### 接入真实 LLM
修改 `polish_idea` 方法：
```v
// 替换 simulate_llm_response()
response := s.llm_client.complete(prompt)!
result := parse_llm_response(response)
```

#### 添加数据库存储
```v
// 使用 PersistentLog 存储创意
import vmodu.infra.db as db

mut store := db.new_persistent_log(db.StoreConfig{
    data_dir: './data/ideas'
})!
```

### 5. 项目结构

```
docs/examples/
├── chy3.v              # 主程序
├── chy3_README.md      # 详细文档
└── chy3_quickstart.md  # 本文件
```

### 6. 下一步

1. 阅读 [详细文档](chy3_README.md)
2. 查看其他示例：
   - `01-hello-actors.v` - Actor 基础
   - `02-event-bus.v` - 事件总线
   - `03-intent-router.v` - 意图路由
3. 接入真实的 OpenAI/Claude API
4. 添加 Web 前端界面

## 技术栈

- **V 0.5.0** - 编程语言
- **VModulith Runtime** - 后端框架
  - Actor 模型
  - EventBus 事件驱动
  - Intent Router 意图路由
  - Health/Metrics 可观测性
