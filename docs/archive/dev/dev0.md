  📚 文档

  1. vmodu/MODULES_GUIDE.md - 各模块功能详细说明
    • Core/Runtime/Event/Intent 层
    • Cluster/Agent/Adapters 层
    • Infra 基础设施层
    • 每个模块都有使用示例
  2. vmodu/BEST_PRACTICES.md - 最佳实践指南
    • V 0.5.0 语法最佳实践
    • Module 开发规范
    • Actor 并发模式
    • 事件驱动架构
    • 区块链集成
    • AI Agent 开发
    • 测试和监控

  🔧 脚手架

  vmodu/scaffold/scaffold.v - 项目生成工具

  // 生成新项目
  scaffold.generate_project('my_app', 'fullstack', '.')!

  // 生成业务模块
  scaffold.generate_module('.', 'payment', ModuleTemplate{
      has_events: true
      has_handlers: true
      has_tests: true
  })!

  可用模板：

  • minimal - 最小化项目
  • web-api - Web API 服务
  • agent-ai - AI Agent 应用
  • blockchain - 区块链应用
  • distributed - 分布式集群
  • fullstack - 全功能项目

  📝 重写后的 chy3 示例

  docs/examples/chy3_scaffold.v - 脚手架版本

  特性：

  • ✅ 使用 Module 接口实现模块化
  • ✅ 基于 Container 的生命周期管理
  • ✅ Actor 并发处理 AI 打磨
  • ✅ EventBus 事件发布/订阅
  • ✅ Intent 意图路由
  • ✅ Planner 任务规划
  • ✅ 健康检查和指标收集
