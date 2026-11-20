# VModulith Runtime - AI Native Backend Operating System

## Project Overview

**VModulith Runtime** is a next-generation AI Native Backend Operating System implemented in **Vlang 0.5.0+**. It combines the modular monolith architecture of Spring Modulith with modern AI × Web3 × Intent × Agent Mesh paradigms.

The core philosophy is: **Intent → Agent → Event → Module**

### Key Features

- **Modular Monolith**: Module boundaries enforced through packages and interfaces
- **Event-Driven**: Lock-free EventBus with goroutine-style concurrency
- **AI Agent Native**: Built-in Agent Mesh with Planner, Tools, and Memory
- **Intent Protocol**: Unified entry point for User / AI / Web3 interactions
- **Actor Runtime**: Lock-free concurrent execution model with mailbox pattern
- **Single Binary Deployment**: Compiles to a single lightweight executable

### Target Performance

- Single machine: 200k - 1M QPS
- Millions of concurrent actors
- Container-friendly (ultra-lightweight)

---

## Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Vlang 0.5.0+ |
| Concurrency | V channels (goroutine-style) |
| Module System | V packages + interfaces |
| Event Bus | Lock-free MPSC queue |
| Actor Runtime | Mailbox + Scheduler |
| WASM Runtime | wasmtime (planned) |
| Web3 Adapters | EVM RPC, Solana RPC (planned) |

---

## Project Structure

```
vmodu/
├── cmd/
│   └── vmodud/
│       └── main.v              # Entry point
│
├── runtime/                    # Actor Runtime (core concurrency engine)
│   └── actor/
│       ├── actor.v             # Actor struct with mailbox
│       └── message.v           # Message protocol
│
├── core/                       # Modulith Core
│   └── module/
│       ├── module.v            # Module interface
│       └── container.v         # Module container
│
├── event/                      # Event Mesh
│   └── bus/
│       └── bus.v               # EventBus implementation
│
├── intent/                     # Intent Protocol
│   ├── protocol/
│   │   └── intent.v            # Intent struct
│   └── router/
│       └── router.v            # Intent router
│
├── agent/                      # Agent Mesh
│   └── runtime/
│       └── agent.v             # Agent runtime & Tool interface
│
├── wasm/                       # WASM Sandbox (planned)
│   └── sandbox/
│
├── modules/                    # Business modules
│   ├── wallet/                 # Wallet module
│   ├── swap/                   # Swap module (example)
│   ├── order/                  # Order module
│   ├── payment/                # Payment module
│   └── ai/                     # AI module
│
├── adapters/                   # External adapters (planned)
│   ├── evm/                    # Ethereum/EVM adapter
│   ├── solana/                 # Solana adapter
│   └── openai/                 # OpenAI adapter
│
├── infra/                      # Infrastructure layer (planned)
│   ├── db/                     # Database
│   ├── cache/                  # Cache
│   └── rpc/                    # RPC clients
│
└── sdk/                        # SDK for clients
    └── client/
```

---

## Build Commands

### Initialize Project

```bash
v mod init vmodu
```

### Run Development Version

```bash
v run cmd/vmodud/main.v
```

### Build Production Binary

```bash
v -prod cmd/vmodud/main.v -o vmodud
```

### Test

```bash
v test .
```

---

## Code Style Guidelines

### Naming Conventions

- **Modules**: lowercase, snake_case (e.g., `wallet`, `swap_module`)
- **Structs**: PascalCase (e.g., `Actor`, `EventBus`, `Container`)
- **Interfaces**: PascalCase (e.g., `Module`, `Tool`)
- **Functions**: snake_case (e.g., `new_actor()`, `handle_event()`)
- **Constants**: UPPER_SNAKE_CASE

### Module Organization

```v
// 1. Module declaration
module actor

// 2. Imports
import runtime.actor
import event.bus

// 3. Constants
const default_mailbox_size = 100

// 4. Structs
pub struct Actor {
pub:
    id string
mut:
    mailbox chan Message
}

// 5. Interfaces
pub interface Module {
    name() string
    init() !
    handle(Message)
}

// 6. Functions
pub fn new_actor(id string) Actor {
    return Actor{
        id: id
        mailbox: chan Message{cap: default_mailbox_size}
    }
}
```

### Concurrency Patterns

- **Always use channels** for actor communication (message passing, not shared memory)
- **Use `go` keyword** for spawning concurrent handlers
- **Channel capacity**: Set reasonable buffer sizes (default: 100)

```v
// Good: Channel-based communication
pub fn (mut a Actor) send(msg Message) {
    a.mailbox <- msg
}

// Good: Goroutine-style concurrency
pub fn (mut b EventBus) publish(e Event) {
    handlers := b.subscribers[e.name]
    for h in handlers {
        go h(e)  // Spawn concurrent handler
    }
}
```

### Error Handling

```v
// Use Result type for fallible operations
pub fn (m Module) init() ! {
    // Initialize resources
    return error('initialization failed') if failed
}

// In container startup
pub fn (mut c Container) start() {
    for _, m in c.modules {
        m.init() or { panic(err) }
    }
}
```

---

## Architecture Patterns

### 1. Actor Model

Each module runs as an Actor with:
- **Mailbox**: Channel for receiving messages
- **ID**: Unique identifier
- **Handler**: Function to process messages

```v
pub struct Actor {
pub:
    id string
mut:
    mailbox chan Message
}

pub fn (mut a Actor) start(handler fn (Message)) {
    go fn (mut a Actor, handler fn (Message)) {
        for {
            msg := <-a.mailbox
            handler(msg)
        }
    }(mut a, handler)
}
```

### 2. Module Interface

All business modules implement the `Module` interface:

```v
pub interface Module {
    name() string      // Module name
    init() !           // Initialize module
    handle(Message)    // Handle incoming message
}
```

### 3. Event Bus Pattern

Modules communicate through events, not direct calls:

```v
// Publish event
event_bus.publish(Event{
    name: 'order_created'
    data: {'id': '123'}
})

// Subscribe to event
event_bus.subscribe('order_created', fn (e Event) {
    // Handle event
})
```

### 4. Intent Protocol

External interactions flow through Intent:

```v
pub struct Intent {
pub:
    actor  string           // Target actor/agent
    action string           // Action to perform
    params map[string]string // Parameters
}

// Routing
match i.action {
    'swap' { handle_swap(i) }
    'transfer' { handle_transfer(i) }
    else { println('unknown intent') }
}
```

### 5. Tool Interface (Agent)

Agent tools implement the `Tool` interface:

```v
pub interface Tool {
    name() string
    run(string) string
}
```

---

## Development Roadmap

### Phase 1: Core Runtime (Current)
- [x] Actor Runtime
- [x] EventBus
- [x] Module Container

### Phase 2: Intent Layer
- [ ] Intent Protocol
- [ ] Intent Router

### Phase 3: Agent Mesh
- [ ] Agent Mesh
- [ ] Tool Runtime
- [ ] Agent Planner

### Phase 4: WASM Sandbox
- [ ] WASM Tool Runtime
- [ ] Plugin System

### Phase 5: Web3 Integration
- [ ] EVM Adapter
- [ ] Solana Adapter
- [ ] Wallet Module

---

## Testing Instructions

### Unit Testing

```bash
# Run all tests
v test .

# Run specific module tests
v test runtime/actor
v test event/bus
```

### Test Structure

```v
// In actor_test.v
module actor

fn test_new_actor() {
    a := new_actor('test-1')
    assert a.id == 'test-1'
    assert a.mailbox != nil
}
```

### Integration Testing

```bash
# Run example swap flow
v run cmd/vmodud/main.v
# Expected output: "swap request received: 10"
```

---

## Security Considerations

### 1. WASM Sandbox (Future)

All AI Agent tools must run in WASM sandbox:
- Isolated execution environment
- Resource limits (CPU, memory)
- No direct system access

### 2. Module Boundaries

- Modules communicate only through **EventBus** and **Intent Router**
- No direct function calls between modules
- Enforced at compile time through interface design

### 3. Input Validation

```v
pub fn route(i Intent) {
    // Validate action
    if i.action !in valid_actions {
        println('invalid intent')
        return
    }
    // Process...
}
```

---

## Key Design Principles

1. **No Direct Module Calls**: Modules communicate only via events and intents
2. **Lock-Free Concurrency**: Use channels, avoid locks
3. **Zero-Copy Messages**: Avoid JSON serialization where possible
4. **Single Binary**: Deployment should be a single executable
5. **AI-Native**: Built from ground up for AI Agent orchestration

---

## References

- **Vlang Documentation**: https://vlang.io/docs
- **Design Document**: `dev.md`
- **Runtime Code Skeleton**: `runtime code.md`

---

## Notes for AI Agents

- This project is currently in **architecture/design phase** with minimal runnable code
- The code examples in documentation should be treated as **design specifications**
- When implementing, follow the **six-layer architecture** strictly
- Prioritize **Vlang idioms** over patterns from other languages (Java/Go)
- The `chan` type in V is the primary concurrency primitive - use it extensively
