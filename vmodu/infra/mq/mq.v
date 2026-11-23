// mq.v - Message Queue for VModulith
// Reuses: net, sync from V standard library
//
// EXPERIMENTAL (external brokers): RabbitMQ / Kafka clients are stubs.
// InMemoryQueue is OK for local/dev and in-process use.

module mq

import net
import time
import sync
import json2
import rand

// MessageQueue interface
pub interface MessageQueue {
	publish(topic string, msg Message) !
	subscribe(topic string, handler fn (Message)) !
}

// Message represents a queue message
pub struct Message {
pub:
	id        string
	topic     string
	payload   string
	headers   map[string]string
	timestamp i64
}

// InMemoryQueue implements in-memory message queue
pub struct InMemoryQueue {
pub mut:
	subscribers map[string][]fn (Message)
	buffer      chan Message
	mu          sync.Mutex
	is_running  bool
}

// new_in_memory_queue creates an in-memory queue
pub fn new_in_memory_queue(buffer_size int) &InMemoryQueue {
	return &InMemoryQueue{
		subscribers: {}
		buffer:      chan Message{cap: buffer_size}
		is_running:  false
	}
}

// start starts the message dispatcher
pub fn (mut q InMemoryQueue) start() {
	if q.is_running {
		return
	}
	
	q.is_running = true
	spawn q.dispatch()
}

// stop stops the message dispatcher
pub fn (mut q InMemoryQueue) stop() {
	q.is_running = false
}

// dispatch dispatches messages to subscribers
fn (mut q InMemoryQueue) dispatch() {
	for q.is_running {
		select {
			msg := <-q.buffer {
				q.mu.lock()
				handlers := q.subscribers[msg.topic] or { [] }
				q.mu.unlock()
				
				for handler in handlers {
					spawn handler(msg)
				}
			}
			100 * time.millisecond {
				// Timeout to check is_running
			}
		}
	}
}

// publish publishes a message
pub fn (mut q InMemoryQueue) publish(topic string, msg Message) ! {
	if !q.is_running {
		return error('queue not running')
	}
	
	q.buffer <- msg
}

// subscribe subscribes to a topic
pub fn (mut q InMemoryQueue) subscribe(topic string, handler fn (Message)) ! {
	q.mu.lock()
	defer { q.mu.unlock() }
	
	if topic !in q.subscribers {
		q.subscribers[topic] = []
	}
	
	q.subscribers[topic] << handler
}

// RabbitMQ implementation
pub struct RabbitMQClient {
pub:
	host     string
	port     int
	username string
	password string
	vhost    string
}

// new_rabbitmq_client creates a RabbitMQ client
pub fn new_rabbitmq_client(host string, port int, username string, password string) &RabbitMQClient {
	return &RabbitMQClient{
		host:     host
		port:     port
		username: username
		password: password
		vhost:    '/'
	}
}

// connect connects to RabbitMQ
pub fn (c &RabbitMQClient) connect() ! {
	// AMQP connection implementation
	// This would use a proper AMQP library
}

// Kafka implementation
pub struct KafkaClient {
pub:
	brokers []string
	topic   string
}

// new_kafka_client creates a Kafka client
pub fn new_kafka_client(brokers []string) &KafkaClient {
	return &KafkaClient{
		brokers: brokers
	}
}

// Message builders

// new_message creates a new message
pub fn new_message(topic string, payload string) Message {
	return Message{
		id:        '${time.now().unix()}_${rand.intn(1000000) or { 0 }}'
		topic:     topic
		payload:   payload
		headers:   {}
		timestamp: time.now().unix()
	}
}

// with_header adds a header
pub fn (mut m Message) with_header(key string, value string) Message {
	m.headers[key] = value
	return m
}

// E-commerce message types

// OrderCreatedMessage
pub struct OrderCreatedMessage {
pub:
	order_id    string
	customer_id string
	amount      f64
	items       []OrderItem
	timestamp   i64
}

pub struct OrderItem {
pub:
	product_id string
	name       string
	quantity   int
	price      f64
}

// to_message converts to Message
pub fn (m &OrderCreatedMessage) to_message() Message {
	return new_message('order.created', json2.encode(m), escape_unicode: true, time_as_unix: true)
}

// PaymentCompletedMessage
pub struct PaymentCompletedMessage {
pub:
	order_id    string
	payment_id  string
	amount      f64
	status      string
	timestamp   i64
}

// to_message converts to Message
pub fn (m &PaymentCompletedMessage) to_message() Message {
	return new_message('payment.completed', json2.encode(m), escape_unicode: true, time_as_unix: true)
}

// InventoryUpdateMessage
pub struct InventoryUpdateMessage {
pub:
	product_id string
	quantity   int
	operation  string  // add, subtract, set
	reason     string
}

// to_message converts to Message
pub fn (m &InventoryUpdateMessage) to_message() Message {
	return new_message('inventory.update', json2.encode(m), escape_unicode: true, time_as_unix: true)
}

// MessageProcessor processes messages
pub struct MessageProcessor {
pub mut:
	queue       &InMemoryQueue
	handlers    map[string]fn (Message) !
}

// new_processor creates a message processor
pub fn new_processor(queue &InMemoryQueue) &MessageProcessor {
	return &MessageProcessor{
		queue:    queue
		handlers: {}
	}
}

// register_handler registers a handler
pub fn (mut p MessageProcessor) register_handler(topic string, handler fn (Message) !) {
	p.handlers[topic] = handler
	
	p.queue.subscribe(topic, fn [handler] (msg Message) {
		handler(msg) or {
			eprintln('Message handler error: ${err}')
		}
	})!
}

// start starts processing
pub fn (mut p MessageProcessor) start() {
	p.queue.start()
}

// Dead letter queue for failed messages
pub struct DeadLetterQueue {
pub mut:
	failed_messages []FailedMessage
	max_retries     int = 3
}

pub struct FailedMessage {
pub:
	message     Message
	error       string
	retry_count int
	failed_at   i64
}

// new_dlq creates a dead letter queue
pub fn new_dlq() &DeadLetterQueue {
	return &DeadLetterQueue{
		failed_messages: []
	}
}

// add adds a failed message
pub fn (mut d DeadLetterQueue) add(msg Message, err string) {
	d.failed_messages << FailedMessage{
		message:     msg
		error:       err
		retry_count: 0
		failed_at:   time.now().unix()
	}
}

// retry_all retries all failed messages
pub fn (mut d DeadLetterQueue) retry_all(publish_fn fn (Message) !) {
	mut remaining := []FailedMessage{}
	
	for fm in d.failed_messages {
		if fm.retry_count < d.max_retries {
			publish_fn(fm.message) or {
				remaining << FailedMessage{
					...fm
					retry_count: fm.retry_count + 1
				}
			}
		}
	}
	
	d.failed_messages = remaining
}
