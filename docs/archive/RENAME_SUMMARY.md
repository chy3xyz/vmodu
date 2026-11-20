# vmodu Runtime → VModu 重命名总结

## 概述

项目已从 `vclaw_runtime` (VClaw Runtime) 重命名为 `vmodu` (VModu)。

## 主要变更

### 1. 模块名变更

| 旧名称 | 新名称 |
|--------|--------|
| `vclaw` | `vmodu` |
| `vclaw_modules` | `vmodu` (目录) |

### 2. 目录结构变更

| 旧路径 | 新路径 |
|--------|--------|
| `vclaw_modules/` | `vmodu/` |
| `cmd/vclaw-cli/` | `cmd/vmodu-cli/` |
| `cmd/vclawctl/` | `cmd/vmoductl/` |
| `cmd/vclawd/` | `cmd/vmodud/` |

### 3. 导入路径变更

所有 V 文件中的 import 语句已从:
```v
import vclaw_modules.core
import vclaw_modules.event.bus
```

变更为:
```v
import vmodu.core
import vmodu.event.bus
```

### 4. 命令行工具变更

| 旧命令 | 新命令 |
|--------|--------|
| `vclaw-cli` | `vmodu-cli` |
| `vclawctl` | `vmoductl` |
| `vclawd` | `vmodud` |

### 5. 环境变量变更

| 旧变量名 | 新变量名 |
|----------|----------|
| `VCLAW_ENV` | `VMODU_ENV` |
| `VCLAW_LOG_LEVEL` | `VMODU_LOG_LEVEL` |
| `VCLAW_HTTP_PORT` | `VMODU_HTTP_PORT` |
| `VCLAW_*` | `VMODU_*` |

### 6. 容器/服务名称变更

| 旧名称 | 新名称 |
|--------|--------|
| `vclaw-api` | `vmodu-api` |
| `vclaw-postgres` | `vmodu-postgres` |
| `vclaw-redis` | `vmodu-redis` |
| `vclaw-*` | `vmodu-*` |

## 修改的文件统计

- **V 源文件**: ~60 个文件
- **Markdown 文档**: ~20 个文件
- **YAML 配置文件**: 5 个文件
- **Shell 脚本**: 3 个文件
- **其他配置**: 若干

**总计**: 81+ 个文件被修改

## 验证结果

### 编译测试

```bash
# 核心模块编译测试
✅ vmodu/core
✅ vmodu/event/bus
✅ vmodu/infra/http
✅ vmodu/scaffold
✅ vmodu/agent/planner
```

### 引用清理检查

- ✅ 小写 `vclaw`: 0 个文件
- ✅ 大写 `VClaw`: 0 个文件
- ✅ 环境变量 `VCLAW_*`: 0 个文件
- ✅ 中间名 `vmodulith`: 0 个文件
- ✅ 中间变量 `VMODULITH_*`: 0 个文件

## 迁移指南

### 对于开发者

1. **更新导入路径**:
   ```v
   // 旧代码
   import vclaw_modules.core
   
   // 新代码
   import vmodu.core
   ```

2. **更新环境变量**:
   ```bash
   # 旧变量
   export VCLAW_ENV=production
   
   # 新变量
   export VMODE_ENV=production
   ```

3. **更新命令**:
   ```bash
   # 旧命令
   vclaw-cli new myapp
   
   # 新命令
   vmodu-cli new myapp
   ```

### 对于部署

1. **更新 Docker Compose**:
   ```bash
   docker-compose -f deploy/docker-compose.yml up
   ```

2. **更新环境配置文件**:
   ```bash
   cp deploy/.env.example deploy/.env
   # 编辑 .env 文件，使用 VMODE_* 前缀的变量
   ```

## 文件清单

### 关键修改文件

- `v.mod` - 模块定义
- `vmodu/core/modulith.v` - 核心模块
- `vmodu/scaffold/scaffold.v` - 脚手架模块
- `cmd/vmodu-cli/main.v` - CLI 工具
- `cmd/vmodud/main.v` - 守护进程
- `cmd/vmoductl/main.v` - 控制工具

### 部署配置

- `deploy/docker-compose.yml`
- `deploy/docker-compose.prod.yml`
- `deploy/docker-compose.full.yml`
- `deploy/Dockerfile`
- `deploy/Makefile`
- `deploy/scripts/deploy.sh`
- `deploy/scripts/health-check.sh`

### 文档

- `docs/*.md` - 所有文档
- `vmodu/BEST_PRACTICES.md`
- `vmodu/MODULES_GUIDE.md`
- `README.md`
- `INSTALL.md`

## 注意事项

1. **GitHub 链接**: 文档中的 GitHub 链接需要手动更新为新的仓库地址。

2. **外部引用**: 如果其他项目依赖此模块，需要更新它们的 `v.mod` 依赖。

3. **数据库名称**: Docker Compose 中的数据库名称已更新为 `vmodu`。

## 完成时间

- **日期**: 2026-03-12
- **最终模块名**: `vmodu`
- **修改文件数**: 81+
