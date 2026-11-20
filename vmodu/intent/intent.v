// intent.v - Intent system for VModulith Runtime
// Intent is the entry point of the system

module intent

// Intent represents a user or system intent
pub struct Intent {
pub mut:
	action string
	params map[string]string
}

// new_intent creates a new Intent
pub fn new_intent(action string) Intent {
	return Intent{
		action: action
		params: {}
	}
}

// with_param adds a parameter to the intent
pub fn (mut i Intent) with_param(key string, value string) Intent {
	i.params[key] = value
	return i
}

// get_param retrieves a parameter value
pub fn (i &Intent) get_param(key string) string {
	return i.params[key] or { '' }
}

// has_param checks if a parameter exists
pub fn (i &Intent) has_param(key string) bool {
	return key in i.params
}

// IntentHandler handles intents
pub interface IntentHandler {
	can_handle(i Intent) bool
	handle(i Intent) string
}

// Router routes intents to appropriate handlers
pub struct Router {
pub mut:
	handlers []IntentHandler
}

// new_router creates a new Router
pub fn new_router() Router {
	return Router{
		handlers: []
	}
}

// register adds a handler to the router
pub fn (mut r Router) register(handler IntentHandler) {
	r.handlers << handler
}

// route routes an intent to the appropriate handler
pub fn (r &Router) route(i Intent) string {
	for handler in r.handlers {
		if handler.can_handle(i) {
			return handler.handle(i)
		}
	}
	return 'no handler found for action: ${i.action}'
}

// IntentType represents different types of intents
pub enum IntentType {
	unknown
	query
	command
	swap
	transfer
	stake
	unstake
	claim
}

// classify_intent classifies an intent by its action
pub fn classify_intent(i Intent) IntentType {
	match i.action.to_lower() {
		'swap', 'exchange', 'trade' { return .swap }
		'transfer', 'send' { return .transfer }
		'stake', 'delegate' { return .stake }
		'unstake', 'undelegate' { return .unstake }
		'claim', 'harvest' { return .claim }
		'query', 'get', 'check', 'fetch' { return .query }
		'execute', 'run', 'do' { return .command }
		else { return .unknown }
	}
}
