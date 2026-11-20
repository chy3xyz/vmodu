# Installation Guide

> **English** | [中文](#安装指南)

Complete installation guide for VModulith Runtime.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Install from Source](#install-from-source)
- [Docker Installation](#docker-installation)
- [Binary Installation](#binary-installation)
- [Verify Installation](#verify-installation)
- [Post-Installation](#post-installation)

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OS | Linux, macOS, BSD, WSL2 | Linux (Ubuntu 22.04+) |
| CPU | 2 cores | 8+ cores |
| RAM | 2 GB | 8+ GB |
| Disk | 100 MB | 1+ GB (for event storage) |
| Network | - | 1 Gbps |

### Required Software

1. **Vlang 0.5.0+**
   ```bash
   # macOS
   brew install vlang
   
   # Linux
   git clone https://github.com/vlang/v
   cd v
   make
   sudo ./v symlink
   
   # Verify
   v version  # Should show 0.5.0 or higher
   ```

2. **Git**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install git
   
   # macOS
   brew install git
   ```

3. **C Compiler** (for wasmtime)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install build-essential
   
   # macOS (Xcode Command Line Tools)
   xcode-select --install
   ```

## Install from Source

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/vmodu-runtime.git
cd vmodu-runtime
```

### 2. Build

```bash
# Development build
make build

# Production build (optimized)
make build-prod

# Or manually:
v -prod cmd/vmodud/main.v -o vmodu
```

### 3. Install

```bash
# Install to /usr/local/bin
sudo make install

# Or install to custom location
make install PREFIX=/opt/vmodu

# Or just use locally
./vmodu --version
```

## Docker Installation

### Using Pre-built Image

```bash
# Pull image
docker pull vmodu/runtime:latest

# Run
docker run -d \
  --name vmodu \
  -p 8080:8080 \
  -p 9090:9090 \
  -p 8081:8081 \
  -v /data/vmodu:/data \
  vmodu/runtime:latest
```

### Building Docker Image

```bash
# Build image
docker build -t vmodu-runtime .

# Run with compose
docker-compose up -d
```

### Dockerfile Example

```dockerfile
FROM vlang:latest AS builder
WORKDIR /app
COPY . .
RUN v -prod cmd/vmodud/main.v -o vmodu

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/vmodu .
CMD ["./vmodu"]
```

## Binary Installation

### Download Release

```bash
# Download latest release
curl -L -o vmodu.tar.gz https://github.com/yourusername/vmodu-runtime/releases/latest/download/vmodu-$(uname -s)-$(uname -m).tar.gz

# Extract
tar -xzf vmodu.tar.gz
sudo mv vmodu /usr/local/bin/
sudo chmod +x /usr/local/bin/vmodu
```

### Package Managers

```bash
# Homebrew (macOS/Linux)
brew tap vmodu/tap
brew install vmodu-runtime

# APT (Debian/Ubuntu)
echo "deb https://apt.vmodu.io stable main" | sudo tee /etc/apt/sources.list.d/vmodu.list
sudo apt-get update
sudo apt-get install vmodu-runtime
```

## Verify Installation

```bash
# Check version
vmodu --version

# Run test
vmodu --test

# Check system requirements
vmodu doctor

# Expected output:
# VModulith Runtime v3.0.0
# ✓ Vlang version: 0.5.0
# ✓ OS: Linux x86_64
# ✓ CPU: 8 cores
# ✓ RAM: 16 GB
# ✓ Disk: 100 GB available
```

## Post-Installation

### 1. Create Data Directory

```bash
sudo mkdir -p /data/vmodu
sudo chown $USER:$USER /data/vmodu
```

### 2. Create Configuration

```bash
mkdir -p ~/.config/vmodu
cat > ~/.config/vmodu/config.json <<EOF
{
  "runtime": {
    "scheduler_workers": 16,
    "max_actors": 1000000
  },
  "gateway": {
    "http_port": 8080,
    "grpc_port": 9090
  },
  "cluster": {
    "enabled": false,
    "node_id": "node-1",
    "bind_addr": "0.0.0.0",
    "bind_port": 9000
  }
}
EOF
```

### 3. Start Service

```bash
# Run directly
vmodu

# Or with systemd
sudo systemctl enable vmodu
sudo systemctl start vmodu

# Check status
sudo systemctl status vmodu
```

### 4. Verify Service

```bash
# Health check
curl http://localhost:8080/health

# Expected: {"status":"healthy","version":"3.0.0"}
```

## Troubleshooting Installation

### "v: command not found"

```bash
# Add to PATH
export PATH=$PATH:/usr/local/v

# Or reinstall
sudo ./v symlink
```

### "undefined: C.wasm_engine_new"

```bash
# Install wasmtime dependencies
# macOS
brew install wasmtime

# Ubuntu/Debian
sudo apt-get install libwasmtime-dev
```

### Permission Denied

```bash
# Fix permissions
chmod +x vmodu
sudo chown root:root vmodu
sudo chmod u+s vmodu  # Setuid if needed
```

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :8080

# Kill process or change port in config
```

## Uninstallation

```bash
# Remove binary
sudo rm /usr/local/bin/vmodu

# Remove data
sudo rm -rf /data/vmodu
rm -rf ~/.config/vmodu

# Remove systemd service
sudo systemctl stop vmodu
sudo systemctl disable vmodu
sudo rm /etc/systemd/system/vmodu.service
```

---

# 安装指南

> [English](#installation-guide) | **中文**

VModulith Runtime 完整安装指南。

## 目录

- [前置要求](#前置要求)
- [从源码安装](#从源码安装)
- [Docker 安装](#docker-安装)
- [二进制安装](#二进制安装)
- [验证安装](#验证安装)
- [安装后配置](#安装后配置)

## 前置要求

### 系统要求

| 组件 | 最低 | 推荐 |
|------|------|------|
| 操作系统 | Linux, macOS, BSD, WSL2 | Linux (Ubuntu 22.04+) |
| CPU | 2 核 | 8+ 核 |
| 内存 | 2 GB | 8+ GB |
| 磁盘 | 100 MB | 1+ GB (事件存储) |
| 网络 | - | 1 Gbps |

### 所需软件

1. **Vlang 0.5.0+**
   ```bash
   # macOS
   brew install vlang
   
   # Linux
   git clone https://github.com/vlang/v
   cd v
   make
   sudo ./v symlink
   
   # 验证
   v version  # 应显示 0.5.0 或更高
   ```

2. **Git**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install git
   
   # macOS
   brew install git
   ```

3. **C 编译器** (用于 wasmtime)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install build-essential
   
   # macOS (Xcode 命令行工具)
   xcode-select --install
   ```

## 从源码安装

### 1. 克隆仓库

```bash
git clone https://github.com/yourusername/vmodu-runtime.git
cd vmodu-runtime
```

### 2. 构建

```bash
# 开发构建
make build

# 生产构建（优化）
make build-prod

# 或手动：
v -prod cmd/vmodud/main.v -o vmodu
```

### 3. 安装

```bash
# 安装到 /usr/local/bin
sudo make install

# 或安装到自定义位置
make install PREFIX=/opt/vmodu

# 或本地使用
./vmodu --version
```

## Docker 安装

### 使用预构建镜像

```bash
# 拉取镜像
docker pull vmodu/runtime:latest

# 运行
docker run -d \
  --name vmodu \
  -p 8080:8080 \
  -p 9090:9090 \
  -p 8081:8081 \
  -v /data/vmodu:/data \
  vmodu/runtime:latest
```

### 构建 Docker 镜像

```bash
# 构建镜像
docker build -t vmodu-runtime .

# 使用 compose 运行
docker-compose up -d
```

## 二进制安装

### 下载发行版

```bash
# 下载最新版本
curl -L -o vmodu.tar.gz https://github.com/yourusername/vmodu-runtime/releases/latest/download/vmodu-$(uname -s)-$(uname -m).tar.gz

# 解压
tar -xzf vmodu.tar.gz
sudo mv vmodu /usr/local/bin/
sudo chmod +x /usr/local/bin/vmodu
```

### 包管理器

```bash
# Homebrew (macOS/Linux)
brew tap vmodu/tap
brew install vmodu-runtime

# APT (Debian/Ubuntu)
echo "deb https://apt.vmodu.io stable main" | sudo tee /etc/apt/sources.list.d/vmodu.list
sudo apt-get update
sudo apt-get install vmodu-runtime
```

## 验证安装

```bash
# 检查版本
vmodu --version

# 运行测试
vmodu --test

# 检查系统要求
vmodu doctor

# 预期输出：
# VModulith Runtime v3.0.0
# ✓ Vlang 版本: 0.5.0
# ✓ 操作系统: Linux x86_64
# ✓ CPU: 8 核
# ✓ 内存: 16 GB
# ✓ 磁盘: 100 GB 可用
```

## 安装后配置

### 1. 创建数据目录

```bash
sudo mkdir -p /data/vmodu
sudo chown $USER:$USER /data/vmodu
```

### 2. 创建配置

```bash
mkdir -p ~/.config/vmodu
cat > ~/.config/vmodu/config.json <<EOF
{
  "runtime": {
    "scheduler_workers": 16,
    "max_actors": 1000000
  },
  "gateway": {
    "http_port": 8080,
    "grpc_port": 9090
  },
  "cluster": {
    "enabled": false,
    "node_id": "node-1",
    "bind_addr": "0.0.0.0",
    "bind_port": 9000
  }
}
EOF
```

### 3. 启动服务

```bash
# 直接运行
vmodu

# 或使用 systemd
sudo systemctl enable vmodu
sudo systemctl start vmodu

# 检查状态
sudo systemctl status vmodu
```

### 4. 验证服务

```bash
# 健康检查
curl http://localhost:8080/health

# 预期: {"status":"healthy","version":"3.0.0"}
```

---

**Next Steps**: Read the [Quick Start Guide](docs/quickstart.md)
