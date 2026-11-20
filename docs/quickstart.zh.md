# 快速开始

**English (default):** [quickstart.md](quickstart.md)

## 前置要求

- **V 0.5.2+**（[源码安装](https://github.com/vlang/v#installing-v-from-source)）
- 可选：Docker（`deploy/`）

```bash
v version
```

## 克隆与运行

```bash
git clone https://github.com/chy3xyz/vmodu.git
cd vmodu
v run main.v
# 或: v -prod -o vmodu main.v && ./vmodu
```

```bash
curl -s http://127.0.0.1:8080/health
curl -s http://127.0.0.1:8080/metrics | head
```

## Docker / 脚手架 / 测试

命令与英文版相同，见 [quickstart.md](quickstart.md)。部署说明：[deploy/README.zh.md](../deploy/README.zh.md)。

## 下一步

- [架构（中文）](architecture.zh.md) · [模块指南](../vmodu/MODULES_GUIDE.md)
- [贡献](../CONTRIBUTING.zh.md)
