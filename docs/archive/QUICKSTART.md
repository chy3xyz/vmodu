# VModulith Runtime Docker 部署 - 快速开始

## 🚀 5 分钟快速启动

### 1. 环境准备

```bash
# 确保 Docker 已安装
docker --version  # >= 24.0
docker-compose --version  # >= 2.20
```

### 2. 启动开发环境

```bash
# 进入项目目录
cd vmodu-runtime

# 使用脚本一键启动
./deploy/scripts/deploy.sh dev up

# 或使用 Make
make dev
```

### 3. 验证部署

```bash
# 健康检查
./deploy/scripts/health-check.sh

# 查看状态
make status

# 测试 API
curl http://localhost:8080/health
```

### 4. 访问服务

| 服务 | 地址 | 说明 |
|------|------|------|
| VModulith API | http://localhost:8080 | 主服务 |
| Grafana | http://localhost:3000 | 监控面板 (admin/admin) |
| Prometheus | http://localhost:9091 | 指标收集 |
| PostgreSQL | localhost:5432 | 数据库 |

---

## 📁 部署文件结构

```
deploy/
├── docker-compose.yml           # 开发环境
├── docker-compose.prod.yml      # 生产环境（3节点集群）
├── docker-compose.full.yml      # 企业环境（完整基础设施）
├── Dockerfile                   # 多阶段构建
├── Makefile                     # 快捷命令
├── README.md                    # 完整文档
├── QUICKSTART.md               # 本文件
├── .env.example                # 环境变量模板
├── scripts/
│   ├── deploy.sh               # 部署脚本
│   ├── health-check.sh         # 健康检查
│   └── init-db.sql             # 数据库初始化
└── config/
    ├── prometheus.yml          # Prometheus 配置
    ├── nginx/nginx.conf        # Nginx 负载均衡
    └── grafana/                # Grafana 配置
```

---

## 🛠️ 常用命令

### 开发环境

```bash
# 启动
make dev

# 查看日志
make dev-logs

# 停止
make dev-down

# 重启
make dev-restart
```

### 生产环境

```bash
# 启动生产环境（需先配置 .env.production）
make prod

# 查看日志
make prod-logs

# 数据库备份
make db-backup
```

### 调试

```bash
# 进入数据库
make db-shell

# 查看资源使用
make top

# 健康检查
./deploy/scripts/health-check.sh
```

---

## 🏗️ 三种部署模式

### 开发模式 (`docker-compose.yml`)
- 单节点 API
- PostgreSQL + Redis
- Prometheus + Grafana
- **适用**: 本地开发、测试

### 生产模式 (`docker-compose.prod.yml`)
- 3节点 API 集群
- PostgreSQL 主从
- Redis Sentinel
- Nginx 负载均衡
- **适用**: 生产环境

### 企业模式 (`docker-compose.full.yml`)
- 5节点 API 集群
- PostgreSQL HA (Patroni)
- Redis Cluster
- Kafka + ClickHouse + MongoDB
- **适用**: 大型企业、SaaS

---

## ⚙️ 环境变量配置

```bash
# 复制模板
cp deploy/.env.example deploy/.env

# 编辑配置
vim deploy/.env
```

关键变量：
- `DB_PASSWORD` - 数据库密码
- `REDIS_PASSWORD` - Redis 密码
- `JWT_SECRET` - JWT 密钥
- `ENCRYPTION_KEY` - 加密密钥

---

## 📝 下一步

- 阅读完整文档: [deploy/README.md](./README.md)
- 查看 API 文档: http://localhost:8080/docs
- 配置监控面板: http://localhost:3000

---

## 🆘 故障排查

### 端口冲突
```bash
# 修改 docker-compose.yml 中的端口映射
ports:
  - "8081:8080"  # 改为 8081
```

### 内存不足
```bash
# Docker Desktop 设置内存 >= 8GB
# 或减少节点数量
```

### 查看日志
```bash
# 所有日志
make dev-logs

# 特定服务
docker logs vmodu-api
docker logs vmodu-postgres
```

---

> 💡 **提示**: 开发环境默认启用热重载，修改代码后自动生效！
