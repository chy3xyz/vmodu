# 部署指南

**English (default):** [README.md](README.md)

本地可不经 Docker：仓库根目录 `v run main.v`，访问 `http://127.0.0.1:8080/health`。  
Compose 栈较重；开源体验请先验证二进制路径。镜像入口为 `main.v`。

## 快速部署

```bash
cd deploy
cp .env.example .env   # 修改全部口令与 JWT_SECRET
docker compose up -d
docker compose -f docker-compose.prod.yml up -d   # 生产文件
```

服务端口、环境变量、备份与监控命令与英文版相同，见 [README.md](README.md)。

Compose 配置冒烟（不启动容器）：`cd deploy && ./scripts/compose-smoke.sh`。无 Docker 时打印 `SKIP` 并以 0 退出；不会覆盖已有 `.env`。

Grafana 示例口令常见为 `admin/admin`——**上线前必须更换**。

## 生产检查清单

- [ ] 修改所有默认密码
- [ ] 配置 SSL
- [ ] 防火墙 / 日志 / 告警
