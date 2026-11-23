# 架构设计

**English (default):** [architecture.md](architecture.md)

面向 **V 0.5.2+**。模块成熟度见根 [README 模块状态表](../README.zh.md) / [英文 README](../README.md)。

## 概述

VModu 采用 **模块化单体 (Modulith)** + **Actor** + **事件驱动**。  
默认入口（`main.v`）：`core` 容器 + `infra/http`（`/health`、`/metrics`）。

架构图、容器 / EventBus / Actor / 基础设施表、`Module` 接口、数据流与 Raft 集群示意与英文版相同，见 [architecture.md](architecture.md)。

## 技术决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 语言 | V | 编译快、内存安全、简单 |
| 架构 | Modulith | 单体简单 + 可扩展模块 |
| 并发 | Actor | 容错、分布友好 |
| 协议 | HTTP（可选 gRPC） | 标准、工具丰富 |

## 相关文档

- [API 参考](api-reference.zh.md) · [部署](../deploy/README.zh.md)
- [最佳实践（中文）](../vmodu/BEST_PRACTICES.zh.md) · [English](../vmodu/BEST_PRACTICES.md)
