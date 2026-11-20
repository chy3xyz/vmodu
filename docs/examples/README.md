# VModulith Runtime Examples

This directory contains example programs demonstrating various features of VModulith Runtime.

## Running Examples

```bash
# Run any example
v run 01-hello-actors.v
v run 02-event-bus.v
# etc.
```

## Example List

### 01-hello-actors.v
**Basic actor creation and message passing**
- Create multiple actors
- Send messages between actors
- Track message counts

### 02-event-bus.v
**Publish-subscribe event pattern**
- Subscribe multiple handlers to same event
- Async event delivery
- Decoupled module communication

### 03-intent-router.v
**Type-safe command routing**
- Register intent handlers
- Route commands to handlers
- Handle unknown commands

### 04-defi-swap.v
**Event-driven DeFi application**
- Price oracle
- Swap execution engine
- Wallet updates
- Notifications
- Multi-module coordination

### chy3.v
**创意分享与 AI 打磨系统**
- 用户创意提交和验证
- AI 自动打磨和评分
- 事件驱动的异步处理
- 指标收集和健康检查
- 完整的 Intent → Agent → Event 流程

📖 [查看详细文档](chy3_README.md)

## Creating Your Own

Use these examples as templates:

```v
module main

// 1. Define your messages/events
struct MyEvent {
    // fields
}

// 2. Create actors/modules
struct MyActor {
    // state
}

// 3. Implement handlers
fn handle_event(e MyEvent) {
    // logic
}

fn main() {
    // 4. Initialize and run
}
```

## Contributing

Have a good example? Submit a PR!

Requirements:
- Clear comments
- Demonstrates one main concept
- Includes expected output
- Self-contained (no external deps)
