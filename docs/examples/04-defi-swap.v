// Example 4: DeFi Swap Engine
// Demonstrates event-driven DeFi application

module main

import time

// Domain Models
struct TokenPair {
    from   string
    to     string
    rate   f64
}

struct SwapRequest {
    user   string
    from   string
    to     string
    amount f64
}

struct SwapEvent {
    user     string
    from     string
    to       string
    amount   f64
    received f64
    tx_hash  string
}

// Event Bus
struct EventBus {
mut:
    handlers map[string][]fn (map[string]string)
}

fn new_bus() EventBus {
    return EventBus{
        handlers: map[string][]fn (map[string]string){}
    }
}

fn (mut b EventBus) on(event string, handler fn (map[string]string)) {
    if event !in b.handlers {
        b.handlers[event] = []fn (map[string]string){}
    }
    b.handlers[event] << handler
}

fn (mut b EventBus) emit(event string, data map[string]string) {
    if event in b.handlers {
        for handler in b.handlers[event] {
            go handler(data)
        }
    }
}

// Modules

struct PriceOracle {
    pairs map[string]TokenPair
}

fn new_oracle() PriceOracle {
    return PricePair{
        pairs: {
            'ETH/USDT': TokenPair{from: 'ETH', to: 'USDT', rate: 2000.0}
            'BTC/USDT': TokenPair{from: 'BTC', to: 'USDT', rate: 40000.0}
            'ETH/BTC':  TokenPair{from: 'ETH', to: 'BTC', rate: 0.05}
        }
    }
}

fn (o PriceOracle) get_rate(from string, to string) f64 {
    key := '${from}/${to}'
    if key in o.pairs {
        return o.pairs[key].rate
    }
    return 0.0
}

struct SwapEngine {
    oracle PriceOracle
mut:
    event_bus &EventBus
}

fn (mut s SwapEngine) execute_swap(req SwapRequest) {
    rate := s.oracle.get_rate(req.from, req.to)
    received := req.amount * rate
    
    println('[SwapEngine] Executing swap:')
    println('  User: ${req.user}')
    println('  From: ${req.amount} ${req.from}')
    println('  To: ${received} ${req.to}')
    println('  Rate: ${rate}')
    
    // Emit event
    s.event_bus.emit('swap_executed', {
        'user': req.user
        'from': req.from
        'to': req.to
        'amount': req.amount.str()
        'received': received.str()
        'tx_hash': '0x' + req.user[..8]
    })
}

struct Wallet {
    balances map[string]f64
}

fn (mut w Wallet) on_swap_completed(data map[string]string) {
    println('[Wallet] Updating balances for: ${data['user']}')
    // Update balance logic here
}

struct NotificationService {}

fn (n NotificationService) on_swap_completed(data map[string]string) {
    println('[Notification] Sending confirmation to: ${data['user']}')
    println('  Swapped ${data['amount']} ${data['from']} → ${data['received']} ${data['to']}')
}

fn main() {
    println('=== DeFi Swap Engine Example ===')
    println('')
    
    mut bus := new_bus()
    oracle := new_oracle()
    
    mut engine := SwapEngine{
        oracle: oracle
        event_bus: &bus
    }
    
    wallet := Wallet{balances: map[string]f64{}}
    notifier := NotificationService{}
    
    // Subscribe to events
    bus.on('swap_executed', fn [wallet] (data map[string]string) {
        wallet.on_swap_completed(data)
    })
    
    bus.on('swap_executed', fn [notifier] (data map[string]string) {
        notifier.on_swap_completed(data)
    })
    
    // Execute swaps
    swaps := [
        SwapRequest{user: 'alice', from: 'ETH', to: 'USDT', amount: 5.0}
        SwapRequest{user: 'bob', from: 'BTC', to: 'USDT', amount: 0.5}
        SwapRequest{user: 'charlie', from: 'ETH', to: 'BTC', amount: 2.0}
    ]
    
    for swap in swaps {
        engine.execute_swap(swap)
        println('')
        time.sleep(100 * time.millisecond)
    }
    
    time.sleep(200 * time.millisecond)
    println('All swaps completed!')
}
