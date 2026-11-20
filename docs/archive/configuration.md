# Configuration Reference

Complete configuration reference for VModu Runtime.

## Configuration Sources

Configuration is loaded in order of priority:
1. Command-line flags (highest)
2. Environment variables
3. Configuration file
4. Default values (lowest)

## Configuration File

Default location: `~/.config/vmodu/config.json`

```json
{
  "runtime": {
    "scheduler_workers": 16,
    "max_actors": 1000000,
    "mailbox_size": 100,
    "worker_queue_size": 10000
  },
  "event": {
    "bus_buffer_size": 1000,
    "store_enabled": true,
    "store_path": "/data/vmodu/events",
    "segment_size": 10000,
    "retention_hours": 168
  },
  "gateway": {
    "enabled": true,
    "http_port": 8080,
    "grpc_port": 9090,
    "websocket_port": 8081,
    "cors_origins": ["*"],
    "rate_limit": 1000
  },
  "wasm": {
    "enabled": true,
    "memory_limit": 16777216,
    "cpu_time_ms": 5000,
    "fuel_limit": 10000000,
    "module_path": "/opt/vmodu/wasm"
  },
  "llm": {
    "provider": "openai",
    "api_key": "${OPENAI_API_KEY}",
    "model": "gpt-4",
    "temperature": 0.7,
    "max_tokens": 2000,
    "timeout_ms": 30000
  },
  "cluster": {
    "enabled": false,
    "node_id": "node-1",
    "bind_addr": "0.0.0.0",
    "bind_port": 9000,
    "raft_port": 9001,
    "seed_nodes": [],
    "replication_factor": 3,
    "virtual_nodes": 150
  },
  "adapters": {
    "evm": {
      "enabled": true,
      "rpc_url": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
      "chain_id": 1,
      "gas_limit": 3000000
    },
    "solana": {
      "enabled": true,
      "rpc_url": "https://api.mainnet-beta.solana.com",
      "commitment": "confirmed"
    }
  },
  "admin": {
    "enabled": true,
    "port": 8082,
    "auth_enabled": true,
    "token": "${ADMIN_TOKEN}",
    "refresh_interval": 5
  },
  "logging": {
    "level": "info",
    "format": "json",
    "output": "stdout",
    "file": "/var/log/vmodu/vmodu.log"
  },
  "metrics": {
    "enabled": true,
    "prometheus_port": 9091,
    "collect_interval": 10
  }
}
```

## Environment Variables

All configuration can be set via environment variables:

```bash
# Runtime
VMODU_SCHEDULER_WORKERS=16
VMODU_MAX_ACTORS=1000000

# Gateway
VMODU_HTTP_PORT=8080
VMODU_GRPC_PORT=9090
VMODU_WS_PORT=8081

# Event Store
VMODU_EVENT_STORE_PATH=/data/vmodu/events
VMODU_EVENT_RETENTION_HOURS=168

# WASM
VMODU_WASM_MEMORY_LIMIT=16777216
VMODU_WASM_CPU_TIME_MS=5000

# LLM
VMODU_LLM_PROVIDER=openai
VMODU_LLM_API_KEY=sk-...
VMODU_LLM_MODEL=gpt-4

# Cluster
VMODU_CLUSTER_ENABLED=true
VMODU_CLUSTER_NODE_ID=node-1
VMODU_CLUSTER_BIND_ADDR=0.0.0.0
VMODU_CLUSTER_BIND_PORT=9000

# Web3
VMODU_ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/...
VMODU_SOLANA_RPC_URL=https://api.mainnet-beta.solana.com

# Admin
VMODU_ADMIN_ENABLED=true
VMODU_ADMIN_PORT=8082
VMODU_ADMIN_TOKEN=secret

# Logging
VMODU_LOG_LEVEL=info
VMODU_LOG_FORMAT=json
```

## Configuration Options

### Runtime

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `scheduler_workers` | int | 16 | Number of scheduler worker threads |
| `max_actors` | int | 1000000 | Maximum number of actors |
| `mailbox_size` | int | 100 | Default actor mailbox capacity |
| `worker_queue_size` | int | 10000 | Worker task queue size |

### Event System

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `bus_buffer_size` | int | 1000 | Event bus buffer size |
| `store_enabled` | bool | true | Enable persistent event storage |
| `store_path` | string | "/data/vmodu/events" | Event storage directory |
| `segment_size` | int | 10000 | Events per segment file |
| `retention_hours` | int | 168 | Event retention period |

### Gateway

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | true | Enable HTTP/gRPC gateway |
| `http_port` | int | 8080 | HTTP API port |
| `grpc_port` | int | 9090 | gRPC port |
| `websocket_port` | int | 8081 | WebSocket port |
| `cors_origins` | []string | ["*"] | Allowed CORS origins |
| `rate_limit` | int | 1000 | Requests per second limit |

### WASM

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | true | Enable WASM runtime |
| `memory_limit` | int | 16777216 | Max WASM memory (bytes) |
| `cpu_time_ms` | int | 5000 | Max WASM execution time |
| `fuel_limit` | int | 10000000 | Max WASM instructions |
| `module_path` | string | "/opt/vmodu/wasm" | WASM modules directory |

### LLM

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `provider` | string | "openai" | LLM provider (openai/anthropic) |
| `api_key` | string | - | API key (use env var) |
| `model` | string | "gpt-4" | Model name |
| `temperature` | float | 0.7 | Sampling temperature |
| `max_tokens` | int | 2000 | Max response tokens |
| `timeout_ms` | int | 30000 | API timeout |

### Cluster

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | false | Enable distributed cluster |
| `node_id` | string | "node-1" | Unique node identifier |
| `bind_addr` | string | "0.0.0.0" | Bind address |
| `bind_port` | int | 9000 | Cluster communication port |
| `raft_port` | int | 9001 | Raft consensus port |
| `seed_nodes` | []string | [] | Initial cluster nodes |
| `replication_factor` | int | 3 | Actor replication factor |
| `virtual_nodes` | int | 150 | Virtual nodes per physical node |

### Adapters

#### EVM

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | true | Enable EVM adapter |
| `rpc_url` | string | - | Ethereum RPC endpoint |
| `chain_id` | int | 1 | Chain ID (1=mainnet) |
| `gas_limit` | int | 3000000 | Max gas per transaction |

#### Solana

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | true | Enable Solana adapter |
| `rpc_url` | string | - | Solana RPC endpoint |
| `commitment` | string | "confirmed" | Confirmation level |

### Admin

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | true | Enable admin dashboard |
| `port` | int | 8082 | Admin UI port |
| `auth_enabled` | bool | true | Enable authentication |
| `token` | string | - | Admin auth token |
| `refresh_interval` | int | 5 | Metrics refresh interval (seconds) |

### Logging

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `level` | string | "info" | Log level (debug/info/warn/error) |
| `format` | string | "json" | Log format (json/text) |
| `output` | string | "stdout" | Output destination |
| `file` | string | - | Log file path |

### Metrics

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | true | Enable metrics collection |
| `prometheus_port` | int | 9091 | Prometheus metrics port |
| `collect_interval` | int | 10 | Collection interval (seconds) |

## Configuration Examples

### Development

```json
{
  "runtime": {
    "scheduler_workers": 4,
    "max_actors": 10000
  },
  "logging": {
    "level": "debug",
    "format": "text"
  },
  "admin": {
    "auth_enabled": false
  }
}
```

### Production Single Node

```json
{
  "runtime": {
    "scheduler_workers": 32,
    "max_actors": 10000000
  },
  "gateway": {
    "rate_limit": 10000
  },
  "logging": {
    "level": "warn",
    "format": "json",
    "file": "/var/log/vmodu/vmodu.log"
  },
  "metrics": {
    "enabled": true
  }
}
```

### Production Cluster

```json
{
  "cluster": {
    "enabled": true,
    "node_id": "node-1",
    "bind_addr": "10.0.0.1",
    "bind_port": 9000,
    "seed_nodes": ["10.0.0.2:9000", "10.0.0.3:9000"],
    "replication_factor": 3
  },
  "adapters": {
    "evm": {
      "rpc_url": "https://eth-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}"
    }
  }
}
```

## Validation

Validate configuration:

```bash
vmodu config validate

# Or check at startup
vmodu --config-check
```

## Reload Configuration

Some settings can be reloaded without restart:

```bash
# Send SIGHUP
kill -HUP $(pidof vmodu)

# Or use API
curl -X POST http://localhost:8080/admin/reload \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

Reloadable settings:
- Logging level
- Rate limits
- LLM parameters
- Adapter endpoints

Non-reloadable (requires restart):
- Port bindings
- Cluster configuration
- Storage paths
