# Testing Guide

Comprehensive testing strategies for VModulith Runtime.

## Testing Levels

1. **Unit Tests** - Individual functions/components
2. **Integration Tests** - Component interactions
3. **System Tests** - End-to-end workflows
4. **Performance Tests** - Load and stress testing
5. **Security Tests** - Vulnerability scanning

## Running Tests

### All Tests

```bash
# Run all tests
make test

# Or
v test .
```

### Specific Modules

```bash
# Test actor runtime
v test runtime/actor

# Test event system
v test event/

# Test cluster
v test cluster/
```

### With Coverage

```bash
# Generate coverage report
v -coverage test .

# View HTML report
open coverage/index.html
```

## Unit Testing

### Writing Unit Tests

```v
// actor_test.v
module actor

fn test_new_actor() {
    a := new_actor('test-1')
    assert a.id == 'test-1'
    assert a.mailbox != nil
}

fn test_actor_send() {
    mut a := new_actor('test-2')
    mut received := false
    
    a.start(fn (msg Message) {
        received = true
    })
    
    a.send(Message{topic: 'test', data: {}})
    time.sleep(10 * time.millisecond)
    
    assert received == true
}
```

### Test Organization

```
runtime/actor/
  ├── actor.v
  ├── message.v
  ├── actor_test.v       # Unit tests
  ├── message_test.v
  └── test_utils.v       # Test helpers
```

### Mocking

```v
// Mock for testing
struct MockHandler {
    calls []Message
}

fn (mut m MockHandler) handle(msg Message) {
    m.calls << msg
}

// Usage in test
fn test_with_mock() {
    mut mock := MockHandler{}
    mut actor := new_actor('mock-test')
    
    actor.start(fn [mut mock] (msg Message) {
        mock.handle(msg)
    })
    
    actor.send(Message{topic: 'test'})
    
    assert mock.calls.len == 1
}
```

## Integration Testing

### Event Bus Integration

```v
// event_integration_test.v
fn test_event_pub_sub() {
    mut bus := new_bus()
    mut received := []string{}
    
    // Subscribe
    bus.subscribe('test.event', fn [mut received] (e Event) {
        received << e.data['value']
    })
    
    // Publish
    bus.publish(Event{
        name: 'test.event'
        data: {'value': 'hello'}
    })
    
    time.sleep(50 * time.millisecond)
    
    assert received.len == 1
    assert received[0] == 'hello'
}
```

### Intent Router Integration

```v
fn test_intent_routing() {
    mut router := new_router()
    mut handled := false
    
    router.register('test.action', fn [mut handled] (i Intent) {
        handled = true
    })
    
    router.route(Intent{
        action: 'test.action'
        params: {}
    })
    
    assert handled == true
}
```

## System Testing

### End-to-End Workflow

```v
// e2e_test.v
fn test_swap_workflow() {
    // Setup system
    mut runtime := setup_test_runtime()
    
    // Create actors
    swap_actor := runtime.create_actor('swap')
    wallet_actor := runtime.create_actor('wallet')
    
    // Send swap intent
    result := runtime.send_intent(Intent{
        action: 'swap'
        params: {
            'from': 'ETH'
            'to': 'USDT'
            'amount': '10'
        }
    })
    
    // Verify
    assert result.success == true
    assert runtime.get_events().len > 0
}
```

### Cluster E2E Test

```bash
# Start test cluster
./scripts/test-cluster.sh up

# Run tests
v test cluster/e2e

# Tear down
./scripts/test-cluster.sh down
```

## Performance Testing

### Benchmarks

```v
// actor_bench.v
import benchmark

fn benchmark_actor_creation() {
    mut b := benchmark.start()
    
    for i := 0; i < 1000000; i++ {
        a := new_actor('actor-${i}')
    }
    
    b.measure('create 1M actors')
}

fn benchmark_message_passing() {
    mut a := new_actor('bench')
    mut received := 0
    
    a.start(fn (msg Message) {
        received++
    })
    
    mut b := benchmark.start()
    
    for i := 0; i < 1000000; i++ {
        a.send(Message{topic: 'test'})
    }
    
    b.measure('send 1M messages')
}
```

### Load Testing

```bash
# Run load test
v run scripts/load_test.v

# With specific parameters
./vmodu benchmark --actors 10000 --messages 1000000 --parallel 100
```

### Memory Leak Detection

```bash
# Run with leak detection
v -gc trace test .

# Or use valgrind
valgrind --leak-check=full ./vmodu
```

## Security Testing

### Fuzzing

```bash
# Install fuzzer
v install fuzz

# Run fuzz tests
v fuzz runtime/actor
```

### WASM Security Tests

```v
fn test_wasm_resource_limits() {
    mut wasm := new_wasm_sandbox()
    wasm.with_limits(memory: 1024, cpu_ms: 100)
    
    // Try to exceed limits
    code := load_wasm('infinite_loop.wasm')
    result := wasm.execute('test', code)
    
    assert result.success == false
    assert result.error.contains('timeout')
}
```

## Test Fixtures

### Fixtures Directory

```
test_fixtures/
  ├── wasm/
  │   ├── echo.wasm
  │   └── calculator.wasm
  ├── configs/
  │   ├── minimal.json
  │   └── full.json
  └── data/
      ├── sample_events.json
      └── sample_transactions.json
```

### Using Fixtures

```v
fn load_fixture(path string) string {
    return os.read_file('test_fixtures/${path}') or { panic(err) }
}

fn test_with_fixture() {
    config := load_fixture('configs/minimal.json')
    runtime := new_runtime_from_config(config)
    
    assert runtime.is_ready() == true
}
```

## Continuous Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup V
        uses: vlang/setup-v@v1
        
      - name: Install dependencies
        run: sudo apt-get install -y libwasmtime-dev
        
      - name: Run tests
        run: v test .
        
      - name: Run benchmarks
        run: v run scripts/benchmark.v
        
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

### Test Matrices

Test on multiple configurations:
- OS: Linux, macOS, Windows
- V versions: 0.5.0, latest
- Build modes: debug, production

## Test Utilities

### Test Helpers

```v
// test_utils.v
module test_utils

pub fn setup_test_runtime() Runtime {
    return new_runtime(Config{
        workers: 4
        max_actors: 1000
    })
}

pub fn cleanup(runtime &Runtime) {
    runtime.stop()
    // Clean up resources
}

pub fn wait_for_condition(condition fn () bool, timeout_ms int) bool {
    start := time.now().unix_milli()
    for time.now().unix_milli() - start < timeout_ms {
        if condition() {
            return true
        }
        time.sleep(1 * time.millisecond)
    }
    return false
}
```

### Assertions

```v
pub fn assert_contains(haystack string, needle string) {
    assert haystack.contains(needle), 
        'Expected "${haystack}" to contain "${needle}"'
}

pub fn assert_eventually(condition fn () bool, timeout_ms int) {
    result := wait_for_condition(condition, timeout_ms)
    assert result == true, 'Condition not met within ${timeout_ms}ms'
}
```

## Debugging Tests

### Verbose Output

```bash
# Verbose test output
v -stats test .

# With debugging
v -g test runtime/actor

# Trace execution
v -trace test .
```

### Failed Test Debugging

```bash
# Run specific test
v test -run test_actor_send runtime/actor

# With GDB
gdb --args v test runtime/actor

# Core dump analysis
ulimit -c unlimited
v test .
# After crash
gdb v core
```

## Test Coverage Goals

| Module | Target | Current |
|--------|--------|---------|
| runtime/actor | 90% | 85% |
| event/* | 85% | 80% |
| intent/* | 90% | 88% |
| agent/* | 80% | 75% |
| wasm/* | 75% | 70% |
| cluster/* | 80% | 65% |

## Best Practices

1. **Test Independence**: Each test should be independent
2. **Fast Tests**: Unit tests should complete in < 100ms
3. **Deterministic**: Tests should produce same results every time
4. **Clear Names**: Test names should describe behavior
5. **Arrange-Act-Assert**: Structure tests clearly

Example:

```v
fn test_actor_should_process_message_when_sent() {
    // Arrange
    mut a := new_actor('test')
    mut processed := false
    
    a.start(fn (msg Message) {
        processed = true
    })
    
    // Act
    a.send(Message{topic: 'test'})
    time.sleep(10 * time.millisecond)
    
    // Assert
    assert processed == true
}
```
