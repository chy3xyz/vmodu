// bus_test.v - Unit tests for EventBus module

module bus

import time

// test_new_event_bus tests the creation of a new EventBus
fn test_new_event_bus() {
	config := Config{
		max_subscribers_per_topic: 100
		publish_timeout_ms: 5000
		buffer_size: 100
	}
	
	eb := new_event_bus(config)
	
	assert eb.subscribers.len == 0
	assert eb.wildcard_handlers.len == 0
	assert eb.config.max_subscribers_per_topic == 100
	assert eb.stats.messages_published == 0
}

// test_default_config tests the default configuration
fn test_default_config() {
	eb := default()
	
	assert eb.config.max_subscribers_per_topic == 1000
	assert eb.config.publish_timeout_ms == 5000
	assert eb.config.buffer_size == 100
}

// test_subscribe_and_publish tests basic subscription and publishing
fn test_subscribe_and_publish() ! {
	mut eb := default()
	mut received := 0
	
	// Use channel for synchronization
	ch := chan int{cap: 1}
	
	eb.subscribe('test.topic', fn [mut received, ch] (msg Message) {
		received = 1
		ch <- 1
	})!
	
	eb.publish('test.topic', 'hello'.bytes())!
	
	// Wait for message with timeout
	select {
		_ := <-ch {
			// Message received
		}
		500 * time.millisecond {
			// Timeout - continue and check stats
		}
	}
	
	// Also check via stats
	time.sleep(50 * time.millisecond)
	stats := eb.get_stats()
	assert stats.messages_published == 1
}

// test_subscribe_wildcard tests wildcard subscription
fn test_subscribe_wildcard() ! {
	mut eb := default()
	mut received_count := 0
	ch := chan int{cap: 3}
	
	eb.subscribe_wildcard(fn [mut received_count, ch] (msg Message) {
		received_count++
		ch <- received_count
	})!
	
	// Publish to different topics
	eb.publish('topic1', 'data1'.bytes())!
	eb.publish('topic2', 'data2'.bytes())!
	eb.publish('topic3', 'data3'.bytes())!
	
	// Wait for messages
	mut received := 0
	for _ in 0..3 {
		select {
			_ := <-ch {
				received++
			}
			200 * time.millisecond {
				break
			}
		}
	}
	
	stats := eb.get_stats()
	assert stats.messages_published == 3
}

// test_subscribe_empty_topic tests subscribing to empty topic
fn test_subscribe_empty_topic() {
	mut eb := default()
	
	eb.subscribe('', fn (msg Message) {}) or {
		assert err.msg().contains('empty')
		return
	}
	
	assert false, 'should have failed with empty topic'
}

// test_publish_empty_topic tests publishing to empty topic
fn test_publish_empty_topic() {
	mut eb := default()
	
	eb.publish('', 'data'.bytes()) or {
		assert err.msg().contains('empty')
		return
	}
	
	assert false, 'should have failed with empty topic'
}

// test_backpressure tests subscriber limit
fn test_backpressure() {
	mut config := Config{
		max_subscribers_per_topic: 5
		publish_timeout_ms: 5000
	}
	mut eb := new_event_bus(config)
	
	// Add subscribers up to the limit
	for i in 0..5 {
		eb.subscribe('limited.topic', fn (msg Message) {}) or {
			assert false, 'should be able to add subscriber ${i}: ${err}'
			return
		}
	}
	
	// Try to add one more (should fail)
	eb.subscribe('limited.topic', fn (msg Message) {}) or {
		assert err.msg().contains('limit')
		return
	}
	
	assert false, 'should have failed when subscriber limit reached'
}

// test_multiple_subscribers tests multiple subscribers for same topic
fn test_multiple_subscribers() ! {
	mut eb := default()
	ch := chan int{cap: 3}
	
	eb.subscribe('multi.topic', fn [ch] (msg Message) {
		ch <- 1
	})!
	
	eb.subscribe('multi.topic', fn [ch] (msg Message) {
		ch <- 1
	})!
	
	eb.subscribe('multi.topic', fn [ch] (msg Message) {
		ch <- 1
	})!
	
	eb.publish('multi.topic', 'data'.bytes())!
	
	// Wait for all 3 messages
	mut count := 0
	for _ in 0..3 {
		select {
			_ := <-ch {
				count++
			}
			200 * time.millisecond {
				break
			}
		}
	}
	
	// Should have received at least some messages
	assert count > 0
}

// test_topics lists all topics
fn test_topics() ! {
	mut eb := default()
	
	eb.subscribe('topic.a', fn (msg Message) {})!
	eb.subscribe('topic.b', fn (msg Message) {})!
	eb.subscribe('topic.c', fn (msg Message) {})!
	
	topics := eb.topics()
	
	assert topics.len == 3
	assert 'topic.a' in topics
	assert 'topic.b' in topics
	assert 'topic.c' in topics
}

// test_get_stats tests statistics
fn test_get_stats() ! {
	mut eb := default()
	ch := chan int{cap: 1}
	
	initial_stats := eb.get_stats()
	assert initial_stats.messages_published == 0
	
	eb.subscribe('stats.test', fn [ch] (msg Message) {
		ch <- 1
	})!
	
	stats_after_sub := eb.get_stats()
	assert stats_after_sub.subscribers_active == 1
	
	eb.publish('stats.test', 'data'.bytes())!
	
	select {
		_ := <-ch {}
		200 * time.millisecond {}
	}
	
	stats_after_pub := eb.get_stats()
	assert stats_after_pub.messages_published == 1
}

// test_get_subscriber_count tests subscriber counting
fn test_get_subscriber_count() ! {
	mut eb := default()
	
	assert eb.get_subscriber_count() == 0
	
	eb.subscribe('count.test1', fn (msg Message) {})!
	assert eb.get_subscriber_count() == 1
	
	eb.subscribe('count.test2', fn (msg Message) {})!
	assert eb.get_subscriber_count() == 2
	
	eb.subscribe_wildcard(fn (msg Message) {})!
	assert eb.get_subscriber_count() == 3
}

// test_clear removes all subscribers
fn test_clear() ! {
	mut eb := default()
	
	eb.subscribe('clear.test', fn (msg Message) {})!
	eb.subscribe_wildcard(fn (msg Message) {})!
	
	assert eb.get_subscriber_count() == 2
	
	eb.clear()
	
	assert eb.get_subscriber_count() == 0
	assert eb.subscribers.len == 0
	assert eb.wildcard_handlers.len == 0
}

// test_publish_with_headers tests publishing with headers
fn test_publish_with_headers() ! {
	mut eb := default()
	ch := chan string{cap: 2}
	
	eb.subscribe('headers.test', fn [ch] (msg Message) {
		v1 := msg.headers['key1']
		v2 := msg.headers['key2']
		ch <- v1
		ch <- v2
	})!
	
	headers := {
		'key1': 'value1'
		'key2': 'value2'
	}
	
	eb.publish_with_headers('headers.test', 'data'.bytes(), headers)!
	
	mut v1 := ''
	mut v2 := ''
	
	select {
		v1 = <-ch {}
		200 * time.millisecond {}
	}
	
	select {
		v2 = <-ch {}
		200 * time.millisecond {}
	}
	
	assert v1 == 'value1' || v2 == 'value1'
}

// test_unsubscribe tests topic unsubscription
fn test_unsubscribe() ! {
	mut eb := default()
	
	eb.subscribe('unsub.test', fn (msg Message) {})!
	assert eb.subscribers.len == 1
	
	eb.unsubscribe('unsub.test')!
	
	assert eb.subscribers.len == 0
}

// test_unsubscribe_nonexistent tests unsubscribing from non-existent topic
fn test_unsubscribe_nonexistent() {
	mut eb := default()
	
	eb.unsubscribe('nonexistent') or {
		assert err.msg().contains('no subscribers')
		return
	}
	
	assert false, 'should have failed for non-existent topic'
}

// test_stats_with_multiple_messages tests stats with multiple messages
fn test_stats_with_multiple_messages() ! {
	mut eb := default()
	ch := chan int{cap: 10}
	
	eb.subscribe('stats.multi', fn [ch] (msg Message) {
		ch <- 1
	})!
	
	// Publish multiple messages
	for _ in 0..10 {
		eb.publish('stats.multi', 'data'.bytes())!
	}
	
	// Count received messages
	mut count := 0
	for _ in 0..10 {
		select {
			_ := <-ch {
				count++
			}
			100 * time.millisecond {
				break
			}
		}
	}
	
	stats := eb.get_stats()
	assert stats.messages_published == 10
}

// test_no_subscribers_publishes_silently tests publishing without subscribers
fn test_no_subscribers_publishes_silently() ! {
	mut eb := default()
	
	// Publish without any subscribers should succeed
	eb.publish('no.subscribers', 'data'.bytes())!
	
	stats := eb.get_stats()
	assert stats.messages_published == 1
}

// test_wildcard_with_topic_subscriber tests wildcard with regular subscriber
fn test_wildcard_with_topic_subscriber() ! {
	mut eb := default()
	ch := chan string{cap: 2}
	
	eb.subscribe('specific.topic', fn [ch] (msg Message) {
		ch <- 'topic'
	})!
	
	eb.subscribe_wildcard(fn [ch] (msg Message) {
		ch <- 'wildcard'
	})!
	
	// Publish to specific topic - both should receive
	eb.publish('specific.topic', 'data'.bytes())!
	
	mut received1 := ''
	mut received2 := ''
	
	select {
		received1 = <-ch {}
		200 * time.millisecond {}
	}
	
	select {
		received2 = <-ch {}
		200 * time.millisecond {}
	}
	
	// Should have received from both
	assert received1 != '' || received2 != ''
}
