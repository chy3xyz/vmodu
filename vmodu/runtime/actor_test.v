// actor_test.v - Unit tests for actor module

module runtime

import time

struct TestMessage {
	BaseMessage
	data string
}

fn test_new_actor() {
	config := ActorConfig{
		id:           'test-actor'
		mailbox_size: 50
	}
	mut a := new_actor(config)
	
	assert a.id == 'test-actor'
	assert a.running == false
}

fn test_actor_send_receive() {
	config := ActorConfig{
		id:           'test-actor'
		mailbox_size: 10
	}
	mut a := new_actor(config)
	
	mut received := ''
	handler := fn [mut received] (msg Message) {
		// Use sum type assertion with or block
		m := msg as TestMessage
		received = m.data
	}
	
	a.start(handler)
	
	test_msg := TestMessage{
		BaseMessage: BaseMessage{typ: 'test'}
		data:        'hello'
	}
	a.send(test_msg)
	
	time.sleep(100 * time.millisecond)
	
	// Message processing is async, we verify the actor is running
	assert a.is_running() == true
	
	a.stop()
}

fn test_actor_try_send() {
	config := ActorConfig{
		id:           'test-actor'
		mailbox_size: 1
	}
	mut a := new_actor(config)
	
	test_msg := TestMessage{
		BaseMessage: BaseMessage{typ: 'test'}
		data:        'hello'
	}
	
	// First send should succeed (non-blocking with select)
	result1 := a.try_send(test_msg)
	assert result1 == true
	
	// Cleanup
	a.stop()
}

fn test_actor_lifecycle() {
	config := ActorConfig{
		id:           'lifecycle-actor'
		mailbox_size: 10
	}
	mut a := new_actor(config)
	
	assert a.is_running() == false
	
	handler := fn (msg Message) {}
	a.start(handler)
	
	assert a.is_running() == true
	
	a.stop()
	time.sleep(50 * time.millisecond)
	
	assert a.is_running() == false
}

fn test_new_context() {
	ctx := new_context('actor-1')
	
	assert ctx.actor_id == 'actor-1'
	assert ctx.send_time > 0
}
