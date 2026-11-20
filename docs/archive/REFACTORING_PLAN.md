# VModulith 全面重构计划

## 目标
将所有旧代码（adapters/, agent/, cluster/, runtime/, infra/等）重构到 `vmodu/` 目录，统一维护一套代码，并增加完整的单元测试。

## 当前状态

| 目录 | 状态 | 说明 |
|------|------|------|
| `vmodu/` | ✅ 已重构 | V 0.5.0 兼容，有单元测试 |
| `adapters/` | ❌ 待重构 | EVM, Solana 适配器 |
| `agent/` | ❌ 待重构 | planner, runtime |
| `cluster/` | ❌ 待重构 | node, shard, raft |
| `runtime/` | ❌ 待重构 | actor, scheduler |
| `core/` | 🚧 进行中 | modulith 模块 |
| `infra/` | ❌ 待重构 | rpc, ws, db(旧) |
| `wasm/` | ❌ 待重构 | sandbox, runtime |

## 重构批次

### 批次 1: 核心框架 ✅
- [x] `vmodu/core/modulith` - 模块核心框架
- [x] `vmodu/actor` - Actor 运行时

### 批次 2: Web3 适配器
- [ ] `vmodu/adapters/evm` - EVM 链适配器
- [ ] `vmodu/adapters/solana` - Solana 适配器

### 批次 3: AI Agent
- [ ] `vmodu/agent/planner` - 任务规划器
- [ ] `vmodu/agent/runtime` - Agent 运行时

### 批次 4: 分布式集群
- [ ] `vmodu/cluster/node` - 集群节点
- [ ] `vmodu/cluster/shard` - 数据分片

### 批次 5: 网络服务
- [ ] `vmodu/infra/rpc` - RPC 网关
- [ ] `vmodu/infra/ws` - WebSocket 服务

### 批次 6: WASM
- [ ] `vmodu/wasm/sandbox` - WASM 沙盒
- [ ] `vmodu/wasm/runtime` - Wasmtime 集成

## 重构规范

### 1. 目录结构
```
vmodu/
├── adapter/           # 统一为 adapter，不是 adapters
│   ├── evm/
│   └── solana/
├── agent/
│   ├── llm/          # 已存在
│   ├── planner/      # 新增
│   └── runtime/      # 新增
├── cluster/
│   ├── node/         # 新增
│   ├── shard/        # 新增
│   └── raft/         # 已存在
├── core/
│   └── modulith/     # 进行中
├── infra/
│   ├── circuit/      # 已存在
│   ├── db/           # 已存在
│   ├── health/       # 已存在
│   ├── metrics/      # 已存在
│   ├── pool/         # 已存在
│   ├── rpc/          # 新增
│   └── ws/           # 新增
├── runtime/
│   ├── actor/        # 进行中
│   └── scheduler/    # 新增
└── wasm/
    ├── sandbox/      # 新增
    └── runtime/      # 新增
```

### 2. 文件命名
- 模块主文件: `模块名.v` (如 `actor.v`)
- 测试文件: `模块名_test.v` (如 `actor_test.v`)
- 接口定义: 在模块主文件中

### 3. 代码规范

#### 头部注释
```v
// actor.v - Actor runtime with mailbox pattern
//
// Features:
//   - Lock-free message passing
//   - Lifecycle management
//
// Usage:
//   mut act := actor.new_actor("worker-1")
//   act.start(fn (msg) { ... })
```

#### 代码组织
```v
module actor

// ============================================================================
// Imports
// ============================================================================

// ============================================================================
// Constants
// ============================================================================

// ============================================================================
// Types
// ============================================================================

// ============================================================================
// Constructor Functions
// ============================================================================

// ============================================================================
// Core Operations
// ============================================================================

// ============================================================================
// Query Operations
// ============================================================================
```

### 4. 接口定义
```v
// Module 是统一接口
pub interface Module {
    name() string
    version() string
    init(event_bus &bus.EventBus) !
    start() !
    stop() !
}
```

### 5. 测试规范
每个模块必须包含:
- 基础功能测试
- 错误处理测试
- 并发测试（如适用）
- 生命周期测试

## 重构脚本

使用自动化脚本加速重构:

```bash
# 创建新模块结构
./scripts/create_module.sh <模块名>

# 运行所有测试
./scripts/test_all.sh

# 检查编译状态
./scripts/check_all.sh
```

## 时间估计

| 批次 | 模块数 | 估计时间 |
|------|--------|----------|
| 批次 1 | 2 | 2天 ✅ |
| 批次 2 | 2 | 3天 |
| 批次 3 | 2 | 2天 |
| 批次 4 | 2 | 3天 |
| 批次 5 | 2 | 2天 |
| 批次 6 | 2 | 2天 |
| **总计** | **12** | **~16天** |

## 开发建议

### 对于开发者

1. **永远不要直接使用旧目录代码**
   ```v
   // ❌ 错误
   import adapters.evm
   import agent.planner
   
   // ✅ 正确
   import vmodu.adapter.evm
   import vmodu.agent.planner
   ```

2. **使用 vmoductl 创建新项目**
   ```bash
   vmoductl new myapp
   ```

3. **贡献代码前先重构**
   - 如果需要在旧目录添加功能，先将其重构到 vmodu

### 对于维护者

1. **逐步废弃旧代码**
   - 在旧目录添加 `// DEPRECATED: Use vmodu/...` 注释
   - 保持旧代码编译通过，但不增加新功能

2. **版本发布**
   - v0.2.0: 完成所有重构
   - v0.3.0: 删除旧目录代码

## 当前可用模块

```v
// ✅ 可安全使用
import vmodu.event.bus
import vmodu.config
import vmodu.infra.health
import vmodu.infra.metrics
import vmodu.infra.circuit
import vmodu.infra.pool
import vmodu.agent.llm
import vmodu.cluster.raft.rpc
```

## 下一步行动

1. **立即**: 修复 core/modulith 和 actor 的编译问题
2. **本周**: 完成批次 2 (EVM, Solana 适配器)
3. **下周**: 完成批次 3 和 4 (Agent, Cluster)
4. **下下周**: 完成批次 5 和 6 (RPC, WASM)
5. **测试**: 确保所有测试通过
6. **文档**: 更新所有文档
7. **发布**: v0.2.0
