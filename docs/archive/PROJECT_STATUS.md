# VModulith Runtime 项目状态

## 项目结构 (单一代码库)

```
vmodu/           # 所有代码统一放在这里
├── MODULES_GUIDE.md     # 模块功能说明文档
├── BEST_PRACTICES.md    # 最佳实践指南
├── scaffold/            # 脚手架模块
│   └── scaffold.v       # 项目生成工具
├── adapters/            # 区块链适配器
│   ├── evm/             # EVM (Ethereum)
│   └── solana/          # Solana
├── agent/               # AI Agent
│   ├── llm/             # LLM 客户端
│   ├── planner/         # 任务规划
│   └── tool/            # 工具系统
├── cluster/             # 分布式集群
│   ├── node/            # 集群节点
│   ├── raft/rpc/        # Raft 共识
│   └── shard/           # 一致性哈希
├── config/              # 配置管理
├── core/                # 模块化单体框架
├── event/bus/           # 事件总线
├── infra/               # 基础设施
│   ├── circuit/         # 熔断器
│   ├── db/              # 数据库
│   ├── health/          # 健康检查
│   ├── logger/          # 日志
│   ├── metrics/         # 指标
│   ├── pool/            # 连接池
│   ├── rpc/             # RPC 网关
│   ├── trace/           # 分布式追踪
│   └── ws/              # WebSocket
├── intent/              # 意图系统
├── runtime/             # Actor 运行时
└── wasm/sandbox/        # WASM 沙箱
```

## 文档列表

| 文档 | 说明 |
|------|------|
| `MODULES_GUIDE.md` | 各模块功能详解和使用示例 |
| `BEST_PRACTICES.md` | V 0.5.0 最佳实践指南 |
| `REFACTOR_PROGRESS.md` | 重构进度和 V 0.5.0 迁移笔记 |

## 脚手架使用

### 生成新项目

```v
import vmodu.scaffold

// 生成项目
scaffold.generate_project('my_app', 'fullstack', '.')!

// 可用模板:
// - minimal     : 最小化项目
// - web-api     : Web API 服务
// - agent-ai    : AI Agent 应用
// - blockchain  : 区块链应用
// - distributed : 分布式集群
// - fullstack   : 全功能项目
```

### 生成业务模块

```v
// 在项目中生成新模块
scaffold.generate_module('.', 'payment', ModuleTemplate{
    has_events:   true
    has_handlers: true
    has_tests:    true
})!
```

## 示例代码

| 示例 | 说明 |
|------|------|
| `docs/examples/chy3.v` | 原版示例 |
| `docs/examples/chy3_scaffold.v` | 脚手架版示例（最佳实践） |

## 测试

```bash
# 运行所有测试
v -enable-globals test vmodu/

# 运行特定模块测试
v -enable-globals test vmodu/core/

# 运行示例
v -enable-globals run docs/examples/chy3_scaffold.v
```

## 当前状态

✅ **17/17 测试通过**
✅ **V 0.5.0 兼容**
✅ **单一代码库**
✅ **脚手架完成**
✅ **文档齐全**
