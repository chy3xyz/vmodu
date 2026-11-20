# VModu Runtime Deployment Guide

**Version**: 3.3.0  
**Last Updated**: 2026-03-10

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Deployment Patterns](#deployment-patterns)
5. [Security](#security)
6. [Monitoring](#monitoring)
7. [Backup and Recovery](#backup-and-recovery)
8. [Scaling](#scaling)
9. [Troubleshooting](#troubleshooting)
10. [Upgrade Procedures](#upgrade-procedures)

---

## Requirements

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| OS | Linux (Ubuntu 20.04+) | Linux (Ubuntu 22.04 LTS) |
| CPU | 2 cores | 4+ cores |
| Memory | 4GB RAM | 8GB+ RAM |
| Disk | 10GB SSD | 100GB+ NVMe SSD |
| Network | 1Gbps | 10Gbps |

### Software Requirements

- **V Language**: 0.5.0 or later
- **Git**: 2.30+
- **OpenSSL**: 1.1.1+ (for TLS)
- **Make**: 4.0+ (optional, for build scripts)

### Network Requirements

| Port | Protocol | Purpose | Exposure |
|------|----------|---------|----------|
| 8080 | TCP/HTTP | HTTP API | Public |
| 8081 | TCP/WS | WebSocket | Public |
| 9000 | TCP | Cluster RPC | Private |
| 12000 | TCP | Raft Consensus | Private |
| 9090 | TCP/gRPC | gRPC API | Public (optional) |

---

## Installation

### From Source

```bash
# 1. Install V language
git clone https://github.com/vlang/v
cd v
make
sudo ./v symlink

# 2. Clone VModu Runtime
cd /opt
git clone https://github.com/vmodu/runtime.git
cd runtime

# 3. Build (v3.3: production mode with all modules)
v -prod -enable-globals -o vmodu .

# 4. Verify installation
./vmodu --version
# Output: VModu Runtime v3.3.0
```

### Docker

```dockerfile
# Dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install V
RUN git clone https://github.com/vlang/v.git /opt/v \
    && cd /opt/v \
    && make \
    && ./v symlink

# Copy and build
COPY . /opt/vmodu
WORKDIR /opt/vmodu
RUN v -prod -enable-globals -o vmodu .

EXPOSE 8080 9000

CMD ["./vmodu", "--config=/etc/vmodu/config.json"]
```

Build and run:

```bash
docker build -t vmodu:3.3.0 .
docker run -p 8080:8080 -p 9000:9000 vmodu:3.3.0
```

### Docker Compose (Multi-Node)

```yaml
version: '3.8'

services:
  node1:
    image: vmodu:3.3.0
    container_name: vmodu-node1
    hostname: node1
    ports:
      - "8080:8080"
      - "9000:9000"
    environment:
      - VMODU_NODE_ID=node1
      - VMODU_HTTP_PORT=8080
      - VMODU_CLUSTER_PORT=9000
      - VMODU_CLUSTER_PEERS=node2:9000,node3:9000
      - VMODU_LOG_LEVEL=info
      - VMODU_LOG_FORMAT=json
    volumes:
      - node1-data:/data
      - ./config:/etc/vmodu
    networks:
      - vmodu-cluster
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3

  node2:
    image: vmodu:3.3.0
    container_name: vmodu-node2
    hostname: node2
    ports:
      - "8081:8080"
      - "9001:9000"
    environment:
      - VMODU_NODE_ID=node2
      - VMODU_HTTP_PORT=8080
      - VMODU_CLUSTER_PORT=9000
      - VMODU_CLUSTER_PEERS=node1:9000,node3:9000
    volumes:
      - node2-data:/data
      - ./config:/etc/vmodu
    networks:
      - vmodu-cluster

  node3:
    image: vmodu:3.3.0
    container_name: vmodu-node3
    hostname: node3
    ports:
      - "8082:8080"
      - "9002:9000"
    environment:
      - VMODU_NODE_ID=node3
      - VMODU_HTTP_PORT=8080
      - VMODU_CLUSTER_PORT=9000
      - VMODU_CLUSTER_PEERS=node1:9000,node2:9000
    volumes:
      - node3-data:/data
      - ./config:/etc/vmodu
    networks:
      - vmodu-cluster

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - vmodu-cluster

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - vmodu-cluster

volumes:
  node1-data:
  node2-data:
  node3-data:
  grafana-data:

networks:
  vmodu-cluster:
    driver: bridge
```

---

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `VMODU_ENV` | Environment (dev/staging/prod) | `dev` | No |
| `VMODU_NODE_ID` | Unique node identifier | `node-1` | Yes |
| `VMODU_HTTP_PORT` | HTTP server port | `8080` | No |
| `VMODU_CLUSTER_PORT` | Cluster RPC port | `9000` | No |
| `VMODU_LOG_LEVEL` | Log level | `info` | No |
| `VMODU_LOG_FORMAT` | Log format (text/json) | `text` | No |
| `VMODU_CONFIG_PATH` | Config file path | `./config.json` | No |
| `VMODU_DATA_DIR` | Data directory | `./data` | No |
| `VMODU_CLUSTER_PEERS` | Comma-separated peer list | - | For cluster |
| `OPENAI_API_KEY` | OpenAI API key | - | For AI features |

### Config File (config.json)

```json
{
  "server": {
    "http_port": 8080,
    "grpc_port": 9090,
    "host": "0.0.0.0",
    "read_timeout": 30,
    "write_timeout": 30,
    "max_body_size": 10485760
  },
  "actor": {
    "mailbox_size": 100,
    "worker_pool_size": 16,
    "max_actors": 10000,
    "supervisor_restart_max": 5
  },
  "cluster": {
    "node_id": "node-1",
    "bind_address": "0.0.0.0",
    "raft_port": 12000,
    "peer_addresses": ["node-2:9000", "node-3:9000"],
    "heartbeat_ms": 100,
    "election_timeout_ms": 1000
  },
  "storage": {
    "data_dir": "./data",
    "segment_size": 10000,
    "buffer_size": 8192,
    "flush_interval_ms": 100,
    "fsync_on_write": true
  },
  "llm": {
    "provider": "openai",
    "api_key": "${OPENAI_API_KEY}",
    "model": "gpt-4",
    "max_tokens": 2048,
    "temperature": 0.7,
    "timeout_ms": 30000,
    "max_retries": 3
  },
  "log": {
    "level": "info",
    "format": "json",
    "output": "stdout",
    "max_size_mb": 100,
    "max_backups": 5,
    "max_age_days": 30
  },
  "circuit_breaker": {
    "failure_threshold": 5,
    "success_threshold": 3,
    "timeout_ms": 60000
  },
  "wasm": {
    "memory_limit": 16777216,
    "cpu_time_limit": 5000,
    "fuel_limit": 10000000
  }
}
```

### Environment-Specific Configs

#### Development (config.dev.json)

```json
{
  "log": { "level": "debug", "format": "text" },
  "storage": { "fsync_on_write": false },
  "llm": { "max_retries": 1 }
}
```

#### Production (config.prod.json)

```json
{
  "log": { "level": "info", "format": "json" },
  "storage": { "fsync_on_write": true },
  "actor": { "supervisor_restart_max": 10 },
  "circuit_breaker": { "failure_threshold": 3 }
}
```

---

## Deployment Patterns

### Single Node (Development)

```bash
# Simple startup
./vmodu --config=config.dev.json

# With environment variables
VMODU_LOG_LEVEL=debug \
VMODU_HTTP_PORT=8080 \
./vmodu
```

### Multi-Node Cluster (Production)

#### Node 1 (Initial Leader)

```bash
VMODU_NODE_ID=node-1 \
VMODU_HTTP_PORT=8080 \
VMODU_CLUSTER_PORT=9000 \
VMODU_DATA_DIR=/data/node1 \
./vmodu
```

#### Node 2 (Join Cluster)

```bash
VMODU_NODE_ID=node-2 \
VMODU_HTTP_PORT=8081 \
VMODU_CLUSTER_PORT=9001 \
VMODU_CLUSTER_PEERS=localhost:9000 \
VMODU_DATA_DIR=/data/node2 \
./vmodu
```

#### Node 3 (Join Cluster)

```bash
VMODU_NODE_ID=node-3 \
VMODU_HTTP_PORT=8082 \
VMODU_CLUSTER_PORT=9002 \
VMODU_CLUSTER_PEERS=localhost:9000,localhost:9001 \
VMODU_DATA_DIR=/data/node3 \
./vmodu
```

### Kubernetes (Production)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vmodu-config
data:
  config.json: |
    {
      "server": { "http_port": 8080 },
      "cluster": { "raft_port": 12000 }
    }
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vmodu
spec:
  serviceName: vmodu-headless
  replicas: 3
  selector:
    matchLabels:
      app: vmodu
  template:
    metadata:
      labels:
        app: vmodu
    spec:
      containers:
      - name: vmodu
        image: vmodu:3.3.0
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 9000
          name: cluster
        - containerPort: 12000
          name: raft
        env:
        - name: VMODU_NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: VMODU_CLUSTER_PEERS
          value: "vmodu-0:9000,vmodu-1:9000,vmodu-2:9000"
        volumeMounts:
        - name: config
          mountPath: /etc/vmodu
        - name: data
          mountPath: /data
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
      volumes:
      - name: config
        configMap:
          name: vmodu-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: vmodu
spec:
  selector:
    app: vmodu
  ports:
  - port: 8080
    targetPort: 8080
  type: LoadBalancer
---
apiVersion: v1
kind: Service
metadata:
  name: vmodu-headless
spec:
  selector:
    app: vmodu
  ports:
  - port: 9000
    name: cluster
  - port: 12000
    name: raft
  clusterIP: None
```

Deploy:

```bash
kubectl apply -f k8s/vmodu.yaml
kubectl rollout status statefulset/vmodu
```

---

## Security

### TLS Configuration

```json
{
  "tls": {
    "enabled": true,
    "cert_path": "/etc/vmodu/tls.crt",
    "key_path": "/etc/vmodu/tls.key",
    "ca_path": "/etc/vmodu/ca.crt",
    "client_auth": "require"
  }
}
```

### Generate Certificates

```bash
# CA
openssl req -x509 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 365

# Server
openssl req -newkey rsa:4096 -keyout server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -out server.crt -days 365

# Client
openssl req -newkey rsa:4096 -keyout client.key -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -out client.crt -days 365
```

### Authentication

```json
{
  "auth": {
    "enabled": true,
    "jwt_secret": "${JWT_SECRET}",
    "token_ttl": 3600,
    "refresh_ttl": 86400
  }
}
```

### Firewall Rules

```bash
# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT

# Allow cluster (internal only)
iptables -A INPUT -p tcp --dport 9000 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 12000 -s 10.0.0.0/8 -j ACCEPT

# Block everything else
iptables -A INPUT -j DROP
```

---

## Monitoring

### Health Checks

```bash
# Liveness (restart if failing)
curl -f http://localhost:8080/health || exit 1

# Readiness (remove from LB if failing)
curl -f http://localhost:8080/ready || exit 1

# Startup (wait before marking ready)
curl -f http://localhost:8080/health
```

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'vmodu'
    static_configs:
      - targets: ['node1:8080', 'node2:8080', 'node3:8080']
    metrics_path: /metrics
```

### Key Metrics to Monitor

| Metric | Warning | Critical |
|--------|---------|----------|
| `vmodu_http_errors_total` rate | > 1% | > 5% |
| `vmodu_actor_mailbox_size` | > 80 | > 95 |
| `vmodu_raft_state` | not leader for 10s | not leader for 30s |
| `vmodu_supervisor_restarts_total` | > 5/min | > 10/min |

### Logging Best Practices

```bash
# JSON logging for production
VMODU_LOG_FORMAT=json \
VMODU_LOG_LEVEL=info \
./vmodu 2>&1 | jq -c 'select(.level == "ERROR")'

# Structured query
jq 'select(.fields.path == "/api/swap")' vmodu.log
```

---

## Backup and Recovery

### Backup Strategy

```bash
#!/bin/bash
# backup.sh

DATE=$(date +%Y%m%d)
BACKUP_DIR=/backups/$DATE

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup data directory
tar -czf $BACKUP_DIR/data.tar.gz /data/vmodu

# Backup config
cp /etc/vmodu/config.json $BACKUP_DIR/

# Upload to S3 (optional)
aws s3 sync $BACKUP_DIR s3://vmodu-backups/$DATE/

# Cleanup old backups (keep 7 days)
find /backups -type d -mtime +7 -exec rm -rf {} +
```

### Point-in-Time Recovery

```bash
# 1. Stop service
systemctl stop vmodu

# 2. Restore data
rm -rf /data/vmodu/*
tar -xzf backup-20260310/data.tar.gz -C /

# 3. Restore config
cp backup-20260310/config.json /etc/vmodu/

# 4. Start service
systemctl start vmodu
```

### Disaster Recovery

| RTO | RPO | Strategy |
|-----|-----|----------|
| 1 hour | 1 hour | Hourly backups + 3-node cluster |
| 15 min | 5 min | Continuous replication + hot standby |
| 5 min | 0 | Multi-region active-active |

---

## Scaling

### Horizontal Scaling

Add nodes to the cluster:

```bash
# New node joins existing cluster
VMODU_NODE_ID=node-4 \
VMODU_CLUSTER_PEERS=node-1:9000,node-2:9000,node-3:9000 \
./vmodu
```

### Vertical Scaling

Increase resources:

```bash
# More worker threads
VMODU_WORKER_POOL_SIZE=32 ./vmodu

# Larger actor limit
VMODU_MAX_ACTORS=100000 ./vmodu

# More mailbox capacity
VMODU_MAILBOX_SIZE=1000 ./vmodu
```

### Auto-Scaling (Kubernetes)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vmodu-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: vmodu
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## Troubleshooting

### Common Issues

#### Port Already in Use

```bash
# Find process
lsof -i :8080
netstat -tlnp | grep 8080

# Kill process
kill -9 <PID>

# Or change port
VMODU_HTTP_PORT=8081 ./vmodu
```

#### Permission Denied

```bash
# Fix permissions
chmod +x ./vmodu
chown -R vmodu:vmodu /data/vmodu
chmod 750 /data/vmodu
```

#### Out of Memory

```bash
# Check memory
free -h
cat /proc/meminfo

# Increase swap (temporary)
sudo fallocate -l 4G /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Reduce limits
VMODU_MAX_ACTORS=1000 \
VMODU_MAILBOX_SIZE=50 \
./vmodu
```

#### Cluster Partition

```bash
# Check node status
curl http://node1:8080/api/v1/cluster/status

# View Raft state
curl http://node1:8080/api/v1/cluster/raft

# Force new election (on suspected leader)
curl -X POST http://node1:8080/api/v1/cluster/raft/step_down
```

### Debug Mode

```bash
# Maximum verbosity
VMODU_LOG_LEVEL=debug \
VMODU_LOG_FORMAT=text \
./vmodu 2>&1 | tee vmodu-$(date +%Y%m%d).log

# With stack traces
VMODU_LOG_LEVEL=trace ./vmodu

# Profile performance
VMODU_PROFILE=cpu ./vmodu
```

### Diagnostic Commands

```bash
# System info
curl http://localhost:8080/api/v1/system/info

# Actor stats
curl http://localhost:8080/api/v1/actors/stats

# Event bus stats
curl http://localhost:8080/api/v1/eventbus/stats

# Supervisor status
curl http://localhost:8080/api/v1/supervisors/status
```

---

## Upgrade Procedures

### Rolling Upgrade (Zero-Downtime)

```bash
#!/bin/bash
# rolling-upgrade.sh

NODES=("node1:8080" "node2:8080" "node3:8080")
NEW_VERSION="3.3.1"

for node in "${NODES[@]}"; do
    echo "Upgrading $node..."
    
    # 1. Drain connections
    curl -X POST "http://$node/api/v1/system/drain"
    
    # 2. Wait for drain
    sleep 10
    
    # 3. Stop service
    ssh $node "systemctl stop vmodu"
    
    # 4. Backup
    ssh $node "tar -czf /backup/pre-upgrade.tar.gz /data/vmodu"
    
    # 5. Deploy new version
    scp vmodu-$NEW_VERSION $node:/opt/vmodu/
    ssh $node "ln -sf /opt/vmodu/vmodu-$NEW_VERSION /opt/vmodu/vmodu"
    
    # 6. Start service
    ssh $node "systemctl start vmodu"
    
    # 7. Verify
    until curl -f "http://$node/health"; do
        sleep 2
    done
    
    echo "$node upgraded successfully"
done
```

### Database Migration

```bash
# Backup before migration
./vmodu-admin backup create

# Run migrations
./vmodu-admin migrate up

# Verify
./vmodu-admin migrate status

# Rollback if needed
./vmodu-admin migrate down
```

### Hot Reload (Config Only)

```bash
# Update config
vim /etc/vmodu/config.json

# Send SIGHUP to reload
kill -HUP <PID>

# Or use API
curl -X POST http://localhost:8080/api/v1/system/reload
```

---

## Support

- **Documentation**: https://docs.vmodu.io
- **Issues**: https://github.com/vmodu/runtime/issues
- **Discussions**: https://github.com/vmodu/runtime/discussions
- **Discord**: https://discord.gg/vmodu
- **Email**: support@vmodu.io

---

**Version**: 3.3.0  
**Last Updated**: 2026-03-10
