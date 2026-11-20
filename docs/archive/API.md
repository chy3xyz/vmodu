# VModulith Runtime API Reference

## Overview

This document provides complete API reference for VModulith Runtime v3.3.0.

---

## Table of Contents

1. [Actor System](#actor-system)
2. [Supervision](#supervision)
3. [Event Bus](#event-bus)
4. [Intent Router](#intent-router)
5. [HTTP Server](#http-server)
6. [WebSocket](#websocket)
7. [Agent & Planner](#agent--planner)
8. [LLM Client](#llm-client)
9. [Raft Consensus](#raft-consensus)
10. [Event Store](#event-store)
11. [Circuit Breaker](#circuit-breaker)
12. [Logger](#logger)
13. [Configuration](#configuration)
14. [WASM Runtime](#wasm-runtime)

---

## Actor System

### Types

```v
// Message interface
pub interface Message {
    msg_type() string
}

// BaseMessage implementation
pub struct BaseMessage {
    typ string
}

// Handler function type (v3.1: Option type for safety)
pub type HandlerFunc = fn (Message)

// Actor struct
pub struct Actor {
    id            string
    mailbox       chan Message
    handler       ?HandlerFunc  // v3.1: Option type
    running       bool
    msg_processed u64
}
```

### Functions

#### new_actor
```v
pub fn new_actor(config ActorConfig) &Actor
```
Create a new actor with configuration.

**Example:**
```v
mut actor := runtime.new_actor(runtime.ActorConfig{
    id: 'worker-1'
    mailbox_size: 100
})
```

#### start
```v
pub fn (mut a Actor) start(handler fn (Message))
```
Start the actor with a message handler.

**Example:**
```v
actor.start(fn (msg runtime.Message) {
    if msg is MyMessage {
        println('Received: ${msg.data}')
    }
})
```

#### send
```v
pub fn (mut a Actor) send(msg Message)
```
Send a message to the actor's mailbox (blocking).

#### try_send
```v
pub fn (mut a Actor) try_send(msg Message) bool
```
Attempt to send without blocking. Returns true if successful.

#### send_with_timeout
```v
pub fn (mut a Actor) send_with_timeout(msg Message, timeout_ms int) !
```
Send with timeout in milliseconds.

#### stop
```v
pub fn (mut a Actor) stop()
```
Stop the actor gracefully.

#### get_stats
```v
pub fn (a &Actor) get_stats() ActorStats
```
Get actor statistics.

**Returns:**
```v
pub struct ActorStats {
    actor_id      string
    running       bool
    msg_processed u64
    mailbox_size  int
}
```

#### drain
```v
pub fn (mut a Actor) drain() int
```
Empty the mailbox without processing. Returns number of messages drained.

---

## Supervision

### Types

```v
// Restart strategies
pub enum RestartStrategy {
    one_for_one    // Restart only the failed child
    one_for_all    // Restart all children
    rest_for_one   // Restart failed and subsequent children
}

// Restart types
pub enum RestartType {
    permanent   // Always restart
    temporary   // Never restart
    transient   // Restart only on abnormal exit
}

// Child specification
pub struct ChildSpec {
    id             string
    start_fn       ?fn () !&Actor  // v3.2: Option function type
    restart        RestartType
    max_restarts   int = 5
    restart_window int = 60  // seconds
}
```

### Functions

#### new_supervisor
```v
pub fn new_supervisor(id string, strategy RestartStrategy) &Supervisor
```
Create a new supervisor with specified strategy.

**Example:**
```v
mut sup := runtime.new_supervisor('main-sup', .one_for_one)
```

#### add_child
```v
pub fn (mut s Supervisor) add_child(spec ChildSpec)
```
Add a child specification to supervisor.

**Example:**
```v
sup.add_child(runtime.ChildSpec{
    id: 'worker-1'
    start_fn: fn () !&runtime.Actor {
        mut a := runtime.new_actor(runtime.ActorConfig{
            id: 'worker-1'
        })
        a.start(fn (msg runtime.Message) {
            println('Working...')
        })
        return a
    }
    restart: .permanent
    max_restarts: 5
    restart_window: 60
})
```

#### start
```v
pub fn (mut s Supervisor) start() !
```
Start the supervisor and all permanent children.

#### stop
```v
pub fn (mut s Supervisor) stop()
```
Stop the supervisor and all children.

#### get_child
```v
pub fn (mut s Supervisor) get_child(id string) ?&Actor
```
Get a child actor by ID.

#### get_stats
```v
pub fn (mut s Supervisor) get_stats() SupervisorStats
```
Get supervisor statistics.

**Returns:**
```v
pub struct SupervisorStats {
    id               string
    strategy         string
    children_total   int
    children_running int
    children_failed  int
    is_running       bool
}
```

#### supervise_actor (Helper)
```v
pub fn supervise_actor(id string, actor_fn fn () !&Actor) !&Supervisor
```
Quick helper to supervise a single actor.

---

## Event Bus

### Types

```v
pub struct Message {
    topic   string
    payload []u8
    headers map[string]string
}

pub type Subscriber = fn (Message)
```

### Functions

#### default
```v
pub fn default() &EventBus
```
Get the default event bus instance.

#### new_event_bus
```v
pub fn new_event_bus(config Config) &EventBus
```
Create a new event bus with custom config.

#### subscribe
```v
pub fn (mut bus EventBus) subscribe(topic string, handler Subscriber) !
```
Subscribe to a topic.

**Example:**
```v
mut b := bus.default()
b.subscribe('orders.created', fn (msg bus.Message) {
    println('New order: ${msg.payload.bytestr()}')
})!
```

#### subscribe_wildcard
```v
pub fn (mut bus EventBus) subscribe_wildcard(handler Subscriber) !
```
Subscribe to all topics.

#### publish
```v
pub fn (mut bus EventBus) publish(topic string, payload []u8) !
```
Publish a message to a topic.

#### publish_with_headers
```v
pub fn (mut bus EventBus) publish_with_headers(topic string, payload []u8, headers map[string]string) !
```
Publish with custom headers.

#### get_stats
```v
pub fn (bus &EventBus) get_stats() Stats
```
Get bus statistics.

---

## Intent Router

### Types

```v
pub struct Intent {
    action string
    params map[string]string
}

pub interface IntentHandler {
    can_handle(i Intent) bool
    handle(i Intent) string
}
```

### Functions

#### new_intent
```v
pub fn new_intent(action string) Intent
```
Create a new intent.

#### with_param
```v
pub fn (mut i Intent) with_param(key string, value string) Intent
```
Add a parameter (chainable).

#### new_router
```v
pub fn new_router() Router
```
Create a new intent router.

#### register
```v
pub fn (mut r Router) register(handler IntentHandler)
```
Register a handler.

#### route
```v
pub fn (r &Router) route(i Intent) string
```
Route an intent to appropriate handler.

**Example:**
```v
mut router := intent.new_router()
router.register(SwapHandler{})
result := router.route(intent.new_intent('swap'))
```

---

## HTTP Server

### Types

```v
pub type HandlerFunc = fn (Context) !Response
pub type Middleware = fn (HandlerFunc) HandlerFunc

pub struct Context {
    request    net_http.Request
    params     map[string]string
    method     string
    path       string
    start_time i64
}

pub struct Response {
    status_code int
    headers     map[string]string
    body        string
}

pub struct ServerConfig {
    port          int = 8080
    host          string = '0.0.0.0'
    read_timeout  int = 30
    write_timeout int = 30
    max_body_size i64 = 10 * 1024 * 1024
}
```

### Functions

#### new_server
```v
pub fn new_server(config ServerConfig) &Server
```
Create a new HTTP server.

**Example:**
```v
mut server := http.new_server(http.ServerConfig{
    port: 8080
    host: '0.0.0.0'
})
```

#### get/post/put/delete
```v
pub fn (mut s Server) get(path string, handler HandlerFunc)
pub fn (mut s Server) post(path string, handler HandlerFunc)
pub fn (mut s Server) put(path string, handler HandlerFunc)
pub fn (mut s Server) delete(path string, handler HandlerFunc)
```
Register route handlers.

**Example:**
```v
server.get('/health', fn (ctx http.Context) !http.Response {
    mut resp := http.new_response()
    resp.json({'status': 'healthy'})
    return resp
})

server.post('/api/users', fn (ctx http.Context) !http.Response {
    mut resp := http.new_response()
    resp.status(201)
    resp.json({'id': '123', 'created': true})
    return resp
})
```

#### use
```v
pub fn (mut s Server) use(mw Middleware)
```
Add middleware.

#### start
```v
pub fn (mut s Server) start() !
```
Start the server.

#### stop
```v
pub fn (mut s Server) stop() !
```
Stop the server gracefully.

#### get_stats
```v
pub fn (s &Server) get_stats() ServerStats
```
Get server statistics.

### Response Methods

```v
// Set JSON body
pub fn (mut r Response) json(data any)

// Set text body
pub fn (mut r Response) text(data string)

// Set status code
pub fn (mut r Response) status(code int)
```

---

## WebSocket

### Types

```v
pub type MessageHandler = fn (Message)
pub type ConnectHandler = fn (Client)

pub struct Client {
    id       string
    topics   []string
    metadata map[string]string
    connected_at i64
}

pub struct Message {
    client_id string
    action    string  // subscribe, unsubscribe, publish
    topic     string
    data      map[string]string
    timestamp i64
}
```

### Functions

#### new_server
```v
pub fn new_server(port int) &WebSocketServer
```
Create a WebSocket server.

#### start/stop
```v
pub fn (mut s WebSocketServer) start() !
pub fn (mut s WebSocketServer) stop()
```

#### add_client/remove_client
```v
pub fn (mut s WebSocketServer) add_client(client_id string)
pub fn (mut s WebSocketServer) remove_client(client_id string)
```

#### broadcast
```v
pub fn (mut s WebSocketServer) broadcast(topic string, data map[string]string)
```
Broadcast to all subscribers of a topic.

#### set_on_connect/set_on_disconnect
```v
pub fn (mut s WebSocketServer) set_on_connect(callback fn (Client))
pub fn (mut s WebSocketServer) set_on_disconnect(callback fn (Client))
```

---

## Agent & Planner

### Types

```v
pub enum Priority {
    low
    medium
    high
    critical
}

pub enum StepStatus {
    pending
    in_progress
    completed
    failed
    skipped
}

pub struct Task {
    id          string
    description string
    priority    Priority
    deadline    ?i64
    constraints []string
}

pub struct Step {
    id          string
    action      string
    description string
    depends_on  []string
    status      StepStatus
    estimated_duration int  // minutes
}

pub struct Plan {
    task_id      string
    goal         string
    steps        []Step
    confidence   f64
    created_at   i64
    estimated_total_duration int
}
```

### Functions

#### new_planner
```v
pub fn new_planner(client &llm.Client) Planner
```
Create a planner with LLM client.

#### decompose
```v
pub fn (mut p Planner) decompose(task Task) !Plan
```
Decompose a task into steps using LLM.

**Example:**
```v
mut planner := planner.new_planner(llm_client)

task := planner.Task{
    id: 'task-1'
    description: 'Deploy new version to production'
    priority: .high
    constraints: ['zero-downtime', 'rollback-capable']
}

plan := planner.decompose(task)!
for step in plan.steps {
    println('${step.id}: ${step.action} (${step.estimated_duration}min)')
}
```

#### get_plan
```v
pub fn (p &Planner) get_plan(task_id string) ?Plan
```
Retrieve a stored plan.

#### update_step_status
```v
pub fn (mut p Planner) update_step_status(task_id string, step_id string, status StepStatus) !
```
Update step execution status.

#### get_execution_order
```v
pub fn (p &Planner) get_execution_order(task_id string) ![]Step
```
Get steps in dependency order.

#### get_plan_progress
```v
pub fn (p &Planner) get_plan_progress(task_id string) f64
```
Get completion percentage (0-100).

---

## LLM Client

### Types

```v
pub enum Provider {
    openai
    anthropic
    local
}

pub struct Config {
    provider       Provider = .openai
    base_url       string = 'https://api.openai.com/v1'
    api_key        string
    model          string = 'gpt-4'
    max_tokens     int = 2048
    temperature    f64 = 0.7
    timeout_ms     int = 30000
    max_retries    int = 3
    cache_enabled  bool = true
}

pub struct Message {
    role    string  // system, user, assistant
    content string
}

pub struct CompletionResponse {
    content       string
    tokens_used   int
    finish_reason string
    model         string
    latency_ms    int
    cached        bool
}
```

### Functions

#### new_client
```v
pub fn new_client(config Config) &Client
```
Create LLM client.

**Example:**
```v
mut client := llm.new_client(llm.Config{
    provider: .openai
    api_key: os.getenv('OPENAI_API_KEY')
    model: 'gpt-4'
})
```

#### complete
```v
pub fn (mut c Client) complete(messages []Message) !CompletionResponse
```
Send completion request.

**Example:**
```v
messages := [
    llm.Message{role: 'system', content: 'You are a helpful assistant'}
    llm.Message{role: 'user', content: 'Hello!'}
]

resp := client.complete(messages)!
println(resp.content)
```

#### complete_simple
```v
pub fn (mut c Client) complete_simple(prompt string) !CompletionResponse
```
Single-turn completion.

#### complete_with_system
```v
pub fn (mut c Client) complete_with_system(system_prompt string, user_prompt string) !CompletionResponse
```
Completion with system message.

---

## Raft Consensus

### Types

```v
pub enum NodeState {
    follower
    candidate
    leader
}

pub struct LogEntry {
    term    int
    index   int
    command string
    data    string
}

pub struct RaftStats {
    id            string
    state         string
    term          int
    log_size      int
    commit_index  int
    last_applied  int
    is_leader     bool
}
```

### Functions

#### new_node
```v
pub fn new_node(id string, peers []string) &RaftNode
```
Create a Raft node.

**Example:**
```v
mut node := raft.new_node('node-1', ['node-2:9000', 'node-3:9000'])
```

#### start/stop
```v
pub fn (mut n RaftNode) start()
pub fn (mut n RaftNode) stop()
```

#### propose
```v
pub fn (mut n RaftNode) propose(command string, data string) !
```
Propose a command (must be leader).

**Example:**
```v
if node.is_leader() {
    node.propose('set', '{"key":"foo","value":"bar"}')!
}
```

#### handle_vote_request
```v
pub fn (mut n RaftNode) handle_vote_request(req VoteRequest) VoteResult
```
Handle incoming vote request.

#### handle_append_entries
```v
pub fn (mut n RaftNode) handle_append_entries(req AppendEntries) AppendResult
```
Handle incoming append entries.

#### get_state/get_term/is_leader
```v
pub fn (n &RaftNode) get_state() NodeState
pub fn (n &RaftNode) get_term() int
pub fn (n &RaftNode) is_leader() bool
```

#### get_stats
```v
pub fn (n &RaftNode) get_stats() RaftStats
```

---

## Event Store

### Types

```v
pub struct PersistedEvent {
    offset    u64
    timestamp i64
    key       string
    value     string
    checksum  string
}

pub struct StoreConfig {
    data_dir           string = './data'
    segment_size       int = 10000
    buffer_size        int = 8192
    flush_interval_ms  int = 100
    fsync_on_write     bool = true
}
```

### Functions

#### new_persistent_log
```v
pub fn new_persistent_log(config StoreConfig) !&PersistentLog
```

#### append
```v
pub fn (mut pl PersistentLog) append(key string, value string) !u64
```
Append an event. Returns offset.

#### read
```v
pub fn (pl &PersistentLog) read(start_offset u64, limit int) ![]PersistedEvent
```
Read events from offset.

#### get_stats
```v
pub fn (pl &PersistentLog) get_stats() StoreStats
```

#### close
```v
pub fn (mut pl PersistentLog) close() !
```

---

## Circuit Breaker

### Types

```v
pub enum State {
    closed     // Normal operation
    open       // Failing, reject requests
    half_open  // Testing recovery
}

pub struct Config {
    name                string
    failure_threshold   int = 5
    success_threshold   int = 3
    timeout_ms          int = 60000
    half_open_max_calls int = 3
}

pub struct Stats {
    state        State
    failures     int
    successes    int
    last_failure i64
}
```

### Functions

#### new
```v
pub fn new(config Config) &CircuitBreaker
```

#### execute
```v
pub fn (mut cb CircuitBreaker) execute(op fn () !string) !string
```
Execute operation with protection.

**Example:**
```v
mut cb := circuit.new(circuit.Config{
    name: 'api-service'
    failure_threshold: 5
})

result := cb.execute(fn () !string {
    return make_api_call()!
})!
```

#### allow
```v
pub fn (mut cb CircuitBreaker) allow() bool
```
Check if operation should be allowed.

#### record_success/record_failure
```v
pub fn (mut cb CircuitBreaker) record_success()
pub fn (mut cb CircuitBreaker) record_failure()
```

#### get_state/get_stats
```v
pub fn (mut cb CircuitBreaker) get_state() State
pub fn (mut cb CircuitBreaker) get_stats() Stats
```

---

## Logger

### Types

```v
pub enum Level {
    debug = 0
    info  = 1
    warn  = 2
    error = 3
    fatal = 4
}

pub enum Format {
    text
    json
}

pub struct Config {
    level          Level = .info
    format         Format = .text
    output         string = 'stdout'
    add_timestamp  bool = true
    rotation_size  i64 = 100 * 1024 * 1024
    rotation_count int = 5
}

pub type Fields = map[string]string
```

### Functions

#### new
```v
pub fn new(config Config) !&Logger
```

#### default
```v
pub fn default() &Logger
```

#### init_global_logger
```v
pub fn init_global_logger(config Config) !
```

#### get_global_logger
```v
pub fn get_global_logger() &Logger
```

### Instance Methods

```v
pub fn (mut l Logger) debug(msg string)
pub fn (mut l Logger) info(msg string)
pub fn (mut l Logger) warn(msg string)
pub fn (mut l Logger) error(msg string)
pub fn (mut l Logger) fatal(msg string)

pub fn (mut l Logger) debug_with_fields(msg string, fields Fields)
pub fn (mut l Logger) info_with_fields(msg string, fields Fields)
pub fn (mut l Logger) warn_with_fields(msg string, fields Fields)
pub fn (mut l Logger) error_with_fields(msg string, fields Fields)
pub fn (mut l Logger) fatal_with_fields(msg string, fields Fields)
```

### Global Functions

```v
pub fn debug(msg string)
pub fn info(msg string)
pub fn warn(msg string)
pub fn error(msg string)
pub fn fatal(msg string)

pub fn debug_with_fields(msg string, fields Fields)
pub fn info_with_fields(msg string, fields Fields)
pub fn warn_with_fields(msg string, fields Fields)
pub fn error_with_fields(msg string, fields Fields)
pub fn fatal_with_fields(msg string, fields Fields)
```

---

## Configuration

### Types

```v
pub struct Config {
    server  ServerConfig
    actor   ActorConfig
    storage StorageConfig
    cluster ClusterConfig
    llm     LLMConfig
    log     LogConfig
}

pub type ChangeHandler = fn (Config) !
pub type ValidateHandler = fn (Config) !
```

### Functions

#### new_manager
```v
pub fn new_manager() &Manager
```

#### load
```v
pub fn (mut m Manager) load(path string) !
```

**Example:**
```v
mut mgr := config.new_manager()
mgr.load('config.json')!
```

#### save
```v
pub fn (mut m Manager) save() !
```

#### get
```v
pub fn (mut m Manager) get() Config
```

#### reload
```v
pub fn (mut m Manager) reload() !
```

#### start_watching/stop_watching
```v
pub fn (mut m Manager) start_watching() !
pub fn (mut m Manager) stop_watching() !
```

#### set_on_change/set_on_validate
```v
pub fn (mut m Manager) set_on_change(handler ChangeHandler)
pub fn (mut m Manager) set_on_validate(handler ValidateHandler)
```

---

## WASM Runtime

### Types

```v
pub struct Config {
    memory_limit   u64 = 16 * 1024 * 1024
    cpu_time_limit u64 = 5000
    fuel_limit     u64 = 10_000_000
}

pub struct Module {
    name       string
    wasm_bytes []u8
    hash       string
}

pub struct Instance {
    id          string
    module_name string
    created_at  i64
    memory_used u64
    cpu_time    u64
    fuel_used   u64
    is_running  bool
}

pub struct RuntimeStats {
    modules_loaded     u64
    instances_created  u64
    active_instances   int
    total_executions   u64
}
```

### Functions

#### new_runtime
```v
pub fn new_runtime(config Config) &Runtime
```

#### load_module
```v
pub fn (mut r Runtime) load_module(name string, wasm_bytes []u8) !Module
```

#### load_module_from_file
```v
pub fn (mut r Runtime) load_module_from_file(name string, path string) !Module
```

**Example:**
```v
mut rt := wasmtime.new_runtime(wasmtime.Config{
    memory_limit: 16 * 1024 * 1024
})

rt.load_module_from_file('tools', './tools.wasm')!
```

#### instantiate
```v
pub fn (mut r Runtime) instantiate(module_name string) !Instance
```

#### execute
```v
pub fn (mut r Runtime) execute(instance_id string, func_name string, args []string) !string
```

**Example:**
```v
instance := rt.instantiate('tools')!
result := rt.execute(instance.id, 'calculate', ['1', '+', '2'])!
```

#### terminate/destroy
```v
pub fn (mut r Runtime) terminate(instance_id string)
pub fn (mut r Runtime) destroy(instance_id string)
```

#### get_stats
```v
pub fn (r &Runtime) get_stats() RuntimeStats
```

---

## Best Practices

### Error Handling

Always use `or` blocks for error handling:

```v
result := risky_operation() or {
    eprintln('Error: ${err}')
    return
}
```

### Resource Management

Use `defer` for cleanup:

```v
file := os.open(path)!
defer { file.close() }
```

### Concurrency

Prefer message passing over shared state:

```v
// Good: Message passing
actor.send(message)

// Avoid: Direct state mutation
shared_state.value = new_value  // Race condition risk
```

### Testing

Use the benchmark module for performance testing:

```v
import vmodu.infra.bench

mut b := bench.new_benchmarker()
b.benchmark('actor_send', 10000, fn () {
    actor.send(msg)
})
b.print_results()
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.3.0 | 2026-03-10 | Complete API documentation |
| 3.2.0 | 2026-03-10 | Added Raft, Supervisor, Network, WASM |
| 3.1.0 | 2026-03-10 | Removed unsafe nil, added HTTP Server |
| 3.0.0 | 2026-03-01 | Initial release |
