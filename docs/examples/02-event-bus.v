// Example 2: Event Bus
// Demonstrates publish-subscribe pattern

module main

import time

struct Event {
    name string
    data map[string]string
}

struct EventBus {
mut:
    subscribers map[string][]fn (Event)
}

fn new_bus() EventBus {
    return EventBus{
        subscribers: map[string][]fn (Event){}
    }
}

fn (mut b EventBus) subscribe(event string, handler fn (Event)) {
    if event !in b.subscribers {
        b.subscribers[event] = []fn (Event){}
    }
    b.subscribers[event] << handler
}

fn (mut b EventBus) publish(e Event) {
    if e.name in b.subscribers {
        for handler in b.subscribers[e.name] {
            go handler(e)
        }
    }
}

// Module 1: User Service
struct UserService {}

fn (s UserService) on_user_created(e Event) {
    println('[UserService] New user: ${e.data['user_id']}')
}

// Module 2: Email Service
struct EmailService {}

fn (s EmailService) on_user_created(e Event) {
    println('[EmailService] Sending welcome email to: ${e.data['email']}')
}

// Module 3: Analytics Service
struct AnalyticsService {}

fn (s AnalyticsService) on_user_created(e Event) {
    println('[AnalyticsService] Tracking signup: ${e.data['source']}')
}

fn main() {
    println('=== Event Bus Example ===')
    
    mut bus := new_bus()
    
    user_svc := UserService{}
    email_svc := EmailService{}
    analytics_svc := AnalyticsService{}
    
    // Multiple services subscribe to same event
    bus.subscribe('user_created', fn [user_svc] (e Event) {
        user_svc.on_user_created(e)
    })
    
    bus.subscribe('user_created', fn [email_svc] (e Event) {
        email_svc.on_user_created(e)
    })
    
    bus.subscribe('user_created', fn [analytics_svc] (e Event) {
        analytics_svc.on_user_created(e)
    })
    
    // Publish events
    for i := 0; i < 3; i++ {
        bus.publish(Event{
            name: 'user_created'
            data: {
                'user_id': 'user_${i}'
                'email': 'user${i}@example.com'
                'source': 'web'
            }
        })
    }
    
    time.sleep(200 * time.millisecond)
    println('All events processed!')
}
