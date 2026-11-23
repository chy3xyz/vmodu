# Architecture

**中文版：** [architecture.zh.md](architecture.zh.md)

Current design targets **V 0.5.2+**. Module maturity: root [README module table](../README.md).

## Overview

VModu uses a **modulith** + **Actor** + **event-driven** hybrid.  
Default process entry (`main.v`) wires: `core` container + `infra/http` (`/health`, `/metrics`).

```
┌─────────────────────────────────────────┐
│           Application Layer              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ Module A│ │ Module B│ │ Module C│   │
│  └────┬────┘ └────┬────┘ └────┬────┘   │
├───────┼───────────┼───────────┼─────────┤
│       │     Event Bus        │          │
│  ┌────┴───────────┴───────────┴────┐   │
│  │        Core Container            │   │
│  └──────────────────────────────────┘   │
├─────────────────────────────────────────┤
│           Infrastructure               │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│  │  HTTP   │ │   DB    │ │  Cache  │  │
│  └─────────┘ └─────────┘ └─────────┘  │
└─────────────────────────────────────────┘
```

## Core components

### 1. Container

Module lifecycle manager: register/unregister, DI, start/stop.

```v
mut container := core.new_container()
container.register('module_name', module)!
container.start()!
```

### 2. Event bus

Pub/sub between modules — async, typed where possible.

```v
bus.subscribe('user.created', handler)
bus.publish(event)
```

### 3. Actor runtime

Independent mailbox per actor, supervision tree, restart strategies.

```v
pub struct Actor {
	id      string
	mailbox chan Message
	handler ?HandlerFunc
}
```

### 4. Infrastructure

| Component | Role |
|-----------|------|
| `infra/http` | HTTP / REST |
| `infra/db/sql` | Database access |
| `infra/cache` | Caching |
| `infra/auth/jwt` | Auth |
| `infra/metrics` | Metrics |

## Module interface

```v
pub interface Module {
mut:
	init(event_bus &bus.EventBus) !
	start() !
	stop() !
}
```

## Data flow

```
HTTP Request → Handler → Service → Actor/DB → Response
                    ↓
              Event Bus → Other Modules
```

## Cluster (optional)

Raft `Transport` is wired for multi-node consensus experiments. See `vmodu/cluster/raft/`.

## Design choices

| Topic | Choice | Why |
|-------|--------|-----|
| Language | V | Fast compile, memory safety, simplicity |
| Shape | Modulith | Simple monolith + modular growth |
| Concurrency | Actor | Fault isolation, distribution-friendly |
| Protocols | HTTP (+ optional gRPC) | Standard tooling |

## Related

- [API reference](api-reference.md)
- [Deploy](../deploy/README.md)
- [Best practices](../vmodu/BEST_PRACTICES.md) · [ZH](../vmodu/BEST_PRACTICES.zh.md)
