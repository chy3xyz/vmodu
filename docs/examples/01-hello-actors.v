// Example 1: Hello Actors
// Demonstrates basic actor creation and message passing

module main

import time

struct Message {
    topic string
    data  string
}

struct Greeter {
    name string
mut:
    mailbox chan Message
    count   int
}

fn new_greeter(name string) Greeter {
    return Greeter{
        name: name
        mailbox: chan Message{cap: 10}
        count: 0
    }
}

fn (mut g Greeter) start() {
    go fn (mut g Greeter) {
        for {
            msg := <-g.mailbox
            g.count++
            println('[${g.name}] #${g.count}: ${msg.topic} - ${msg.data}')
        }
    }(mut g)
}

fn (mut g Greeter) send(msg Message) {
    g.mailbox <- msg
}

fn main() {
    println('=== Hello Actors Example ===')
    
    mut alice := new_greeter('Alice')
    mut bob := new_greeter('Bob')
    
    alice.start()
    bob.start()
    
    // Send messages
    alice.send(Message{topic: 'greeting', data: 'Hello from main!'})
    bob.send(Message{topic: 'greeting', data: 'Hi there!'})
    alice.send(Message{topic: 'question', data: 'How are you?'})
    
    time.sleep(100 * time.millisecond)
    
    println('Messages processed: Alice=${alice.count}, Bob=${bob.count}')
}
