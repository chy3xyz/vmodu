// Example 3: Intent Router
// Demonstrates type-safe command routing

module main

struct Intent {
    action string
    params map[string]string
}

type Handler = fn (Intent)

struct Router {
mut:
    handlers map[string]Handler
}

fn new_router() Router {
    return Router{
        handlers: map[string]Handler{}
    }
}

fn (mut r Router) register(action string, handler Handler) {
    r.handlers[action] = handler
}

fn (mut r Router) route(i Intent) {
    if i.action in r.handlers {
        r.handlers[i.action](i)
    } else {
        println('Unknown action: ${i.action}')
    }
}

// Command Handlers

fn handle_create_order(i Intent) {
    println('Creating order:')
    println('  Product: ${i.params['product']}')
    println('  Quantity: ${i.params['qty']}')
    println('  Price: ${i.params['price']}')
}

fn handle_cancel_order(i Intent) {
    println('Cancelling order: ${i.params['order_id']}')
}

fn handle_get_status(i Intent) {
    println('Status for: ${i.params['entity']}')
    println('  Result: ACTIVE')
}

fn main() {
    println('=== Intent Router Example ===')
    
    mut router := new_router()
    
    // Register handlers
    router.register('create_order', handle_create_order)
    router.register('cancel_order', handle_cancel_order)
    router.register('get_status', handle_get_status)
    
    // Route intents
    router.route(Intent{
        action: 'create_order'
        params: {
            'product': 'ETH'
            'qty': '10'
            'price': '2000'
        }
    })
    
    router.route(Intent{
        action: 'get_status'
        params: {'entity': 'system'}
    })
    
    router.route(Intent{
        action: 'unknown_action'
        params: {}
    })
}
