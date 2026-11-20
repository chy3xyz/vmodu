# 贡献指南

感谢贡献 VModu。

**English (default):** [CONTRIBUTING.md](CONTRIBUTING.md)

## 行为准则

参与本项目即表示你同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

## 开发环境

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu
v version   # 需要 V 0.5.2+
```

冒烟：

```bash
v -o /tmp/vmodu_main main.v
/tmp/vmodu_main &
curl -s http://127.0.0.1:8080/health
```

## 代码规范

- 遵循 [V 语言文档](https://github.com/vlang/v/blob/master/doc/docs.md)
- `snake_case`：函数与变量；`PascalCase`：类型
- 公共 API 变更请同步模块文档或根 README 模块表
- 新增实验能力请标 ⚠️ / experimental

## 测试

**不建议**整仓 `v test .`。推荐路径见英文版 [CONTRIBUTING.md](CONTRIBUTING.md#tests)。

## CI / PR / 安全 / 许可

见英文版；安全披露见 [SECURITY.zh.md](SECURITY.zh.md)。贡献默认按 [MIT](LICENSE) 许可。
