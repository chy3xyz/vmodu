// bus.v - Thread-safe EventBus for pub/sub messaging
//
// Features:
//   - Async message delivery with spawn
//   - Topic-based and wildcard subscriptions
//   - Backpressure limiting (max subscribers per topic)
//   - Thread-safe statistics tracking
//
// Usage:
//   mut bus := bus.default()
//   bus.subscribe('orders.created', fn (msg Message) {
//       println('Received: ${msg.payload}')
//   })!
//   bus.publish('orders.created', 'data'.bytes())!

module bus

import sync
import time as _

// ============================================================================
// Types
// ============================================================================

// Message represents an event message
pub struct Message {
pub:
	topic   string
	payload []u8
	headers map[string]string
}

// Subscriber is a function that receives messages
pub type Subscriber = fn (Message)

// Config for EventBus
pub struct Config {
pub mut:
	max_subscribers_per_topic int = 1000 // Backpressure limit
	publish_timeout_ms        int = 5000 // Timeout for publish operations
	buffer_size               int = 100  // Channel buffer size for async handlers
}

// Stats tracks EventBus metrics
pub struct Stats {
pub mut:
	messages_published u64
	messages_delivered u64
	delivery_errors    u64
	subscribers_active int
}

// EventBus is a thread-safe pub/sub message bus
pub struct EventBus {
pub mut:
	subscribers       map[string][]Subscriber
	wildcard_handlers []Subscriber
	mu                sync.RwMutex
	config            Config
	stats             Stats
}

// ============================================================================
// Constructor Functions
// ============================================================================

// new_event_bus creates a new thread-safe EventBus
pub fn new_event_bus(config Config) &EventBus {
	return &EventBus{
		subscribers:       {}
		wildcard_handlers: []
		config:            config
		stats:             Stats{}
	}
}

// default creates an EventBus with default config
pub fn default() &EventBus {
	return new_event_bus(Config{})
}

// ============================================================================
// Subscription Management
// ============================================================================

// subscribe registers a subscriber for a topic
pub fn (mut bus EventBus) subscribe(topic string, handler Subscriber) ! {
	if topic == '' {
		return error('topic cannot be empty')
	}

	bus.mu.lock()
	defer { bus.mu.unlock() }

	if bus.subscribers[topic].len >= bus.config.max_subscribers_per_topic {
		return error('subscriber limit reached for topic: ${topic}')
	}

	bus.subscribers[topic] << handler
	bus.stats.subscribers_active++
}

// subscribe_wildcard registers a subscriber for all topics
pub fn (mut bus EventBus) subscribe_wildcard(handler Subscriber) ! {
	bus.mu.lock()
	defer { bus.mu.unlock() }

	if bus.wildcard_handlers.len >= bus.config.max_subscribers_per_topic {
		return error('wildcard subscriber limit reached')
	}

	bus.wildcard_handlers << handler
	bus.stats.subscribers_active++
}

// unsubscribe removes all subscribers from a topic
pub fn (mut bus EventBus) unsubscribe(topic string) ! {
	bus.mu.lock()
	defer { bus.mu.unlock() }

	if topic !in bus.subscribers {
		return error('no subscribers for topic: ${topic}')
	}

	bus.stats.subscribers_active -= bus.subscribers[topic].len
	bus.subscribers.delete(topic)
}

// ============================================================================
// Publishing
// ============================================================================

// publish sends a message to all subscribers of a topic
pub fn (mut bus EventBus) publish(topic string, payload []u8) ! {
	if topic == '' {
		return error('topic cannot be empty')
	}

	msg := Message{
		topic:   topic
		payload: payload
		headers: {}
	}

	bus.deliver_message(msg)
}

// publish_with_headers sends a message with custom headers
pub fn (mut bus EventBus) publish_with_headers(topic string, payload []u8, headers map[string]string) ! {
	if topic == '' {
		return error('topic cannot be empty')
	}

	msg := Message{
		topic:   topic
		payload: payload
		headers: headers.clone()
	}

	bus.deliver_message(msg)
}

// deliver_message handles actual message delivery
fn (mut bus EventBus) deliver_message(msg Message) {
	// Get subscribers snapshot under read lock
	bus.mu.rlock()
	topic_subs := bus.subscribers[msg.topic].clone()
	wildcard_subs := bus.wildcard_handlers.clone()
	bus.mu.runlock()

	// Deliver asynchronously to topic subscribers
	for handler in topic_subs {
		spawn fn [handler, msg] () {
			handler(msg)
		}()
	}

	// Deliver asynchronously to wildcard subscribers
	for handler in wildcard_subs {
		spawn fn [handler, msg] () {
			handler(msg)
		}()
	}

	// Update stats
	bus.mu.lock()
	bus.stats.messages_published++
	bus.stats.messages_delivered += u64(topic_subs.len + wildcard_subs.len)
	bus.mu.unlock()
}

// ============================================================================
// Query Operations
// ============================================================================

// get_stats returns current statistics (thread-safe copy)
pub fn (bus &EventBus) get_stats() Stats {
	unsafe { bus.mu.rlock() }
	defer { unsafe { bus.mu.runlock() } }
	return bus.stats
}

// get_subscriber_count returns total number of active subscribers
pub fn (bus &EventBus) get_subscriber_count() int {
	unsafe { bus.mu.rlock() }
	defer { unsafe { bus.mu.runlock() } }
	return bus.stats.subscribers_active
}

// topics returns list of all topics with subscribers
pub fn (bus &EventBus) topics() []string {
	unsafe { bus.mu.rlock() }
	defer { unsafe { bus.mu.runlock() } }

	mut result := []string{cap: bus.subscribers.len}
	for topic, _ in bus.subscribers {
		result << topic
	}
	return result
}

// ============================================================================
// Lifecycle
// ============================================================================

// clear removes all subscribers
pub fn (mut bus EventBus) clear() {
	bus.mu.lock()
	defer { bus.mu.unlock() }

	bus.subscribers = {}
	bus.wildcard_handlers = []
	bus.stats = Stats{}
}
