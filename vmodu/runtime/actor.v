// actor.v - Actor Runtime with Mailbox Pattern
// v3.1: Refactored to remove unsafe { nil } patterns

module runtime

import time

// Message is the base interface for all messages
pub interface Message {
	msg_type() string
}

// BaseMessage provides a simple message implementation
pub struct BaseMessage {
pub:
	typ string
}

fn (m BaseMessage) msg_type() string {
	return m.typ
}

// HandlerFunc is the function signature for message handlers
pub type HandlerFunc = fn (Message)

// Actor is the core execution unit
pub struct Actor {
pub:
	id string
pub mut:
	mailbox       chan Message
	handler       ?HandlerFunc  // v3.1: Replaced unsafe { nil } with Option
	running       bool
	msg_processed u64           // v3.1: Added metrics
}

// ActorConfig for configuring an actor
pub struct ActorConfig {
pub:
	id            string
	mailbox_size  int = 100
}

// new_actor creates a new Actor
pub fn new_actor(config ActorConfig) &Actor {
	return &Actor{
		id:       config.id
		mailbox:  chan Message{cap: config.mailbox_size}
		running:  false
		handler:  none  // v3.1: Use Option instead of unsafe nil
	}
}

// send delivers a message to the actor's mailbox (blocking)
pub fn (mut a Actor) send(msg Message) {
	a.mailbox <- msg
}

// try_send attempts to deliver a message without blocking
// Returns true if sent, false if mailbox is full
pub fn (mut a Actor) try_send(msg Message) bool {
	select {
		a.mailbox <- msg {
			return true
		}
		else {
			return false
		}
	}
	return false
}

// start begins message processing
pub fn (mut a Actor) start(handler fn (Message)) {
	a.running = true
	a.handler = handler
	
	spawn fn (mut a Actor) {
		for a.running {
			select {
				msg := <-a.mailbox {
					// v3.1: Safe handler invocation with Option
					if h := a.handler {
						h(msg)
						a.msg_processed++
					}
				}
				500 * time.millisecond {
					// Timeout to periodically check running flag
				}
			}
		}
	}(mut a)
}

// stop halts the actor
pub fn (mut a Actor) stop() {
	a.running = false
	a.handler = none  // v3.1: Clear handler reference
}

// is_running returns actor status
pub fn (a &Actor) is_running() bool {
	return a.running
}

// get_stats returns actor statistics
pub fn (a &Actor) get_stats() ActorStats {
	return ActorStats{
		actor_id:      a.id
		running:       a.running
		msg_processed: a.msg_processed
		mailbox_size:  int(a.mailbox.len)
	}
}

// ActorStats contains actor metrics
pub struct ActorStats {
pub:
	actor_id      string
	running       bool
	msg_processed u64
	mailbox_size  int
}

// Context provides actor execution context
pub struct Context {
pub:
	actor_id    string
	send_time   i64
}

// new_context creates a new Context
pub fn new_context(actor_id string) Context {
	return Context{
		actor_id:  actor_id
		send_time: time.now().unix_milli()
	}
}

// SendWithTimeout sends a message with timeout
// Returns error if timeout expires
pub fn (mut a Actor) send_with_timeout(msg Message, timeout_ms int) ! {
	select {
		a.mailbox <- msg {
			return
		}
		(timeout_ms * time.millisecond) {
			return error('timeout sending message to actor ${a.id}')
		}
	}
}

// Drain empties the mailbox without processing
// Useful during graceful shutdown
pub fn (mut a Actor) drain() int {
	mut count := 0
	for {
		select {
			_ := <-a.mailbox {
				count++
			}
			else {
				return count
			}
		}
	}
	return count
}
