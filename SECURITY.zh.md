# 安全政策

**English (default):** [SECURITY.md](SECURITY.md)

## 支持版本

| 版本 | 支持 |
|------|------|
| `main` / 0.2.x | 是（积极修复） |
| 0.1.x 标签 | 尽力而为 |
| 更早归档标签 | 尽力而为 |

实验模块（WASM 模拟、部分链适配、LLM）不视为默认生产路径的安全边界。

## 报告漏洞

请**不要**在公开 Issue 中贴出利用细节。

1. 优先使用 GitHub **Private vulnerability reporting**（仓库 *Security* 页）
2. 或邮件联系维护者
3. 仅描述「存在问题、模块、版本」的非公开沟通（勿贴完整 exploit）

请包含：受影响版本 / commit、复现步骤、影响评估。

## 运维注意

- 部署前替换 `deploy/.env.example` 中全部密钥
- 默认 HTTP **无 TLS**，生产请置于反向代理之后
- 勿将密钥提交进仓库
