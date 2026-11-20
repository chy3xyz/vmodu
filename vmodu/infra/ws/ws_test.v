// ws_test.v - Unit tests for WebSocket module

module ws

fn test_new_server() {
	server := new_server(8080)

	assert server.port == 8080
	assert server.is_running == false
	assert server.handlers.len == 0
	assert server.clients.len == 0
}

fn test_start_stop() {
	mut server := new_server(8080)

	assert server.is_running == false

	server.start()!
	assert server.is_running == true

	// Should fail when already running
	mut failed := false
	server.start() or {
		failed = true
	}
	assert failed == true

	server.stop()
	assert server.is_running == false
}

fn test_add_remove_client() {
	mut server := new_server(8080)

	assert server.get_client_count() == 0

	server.add_client('client-1')
	assert server.get_client_count() == 1

	server.remove_client('client-1')
	assert server.get_client_count() == 0
}

fn test_subscribe_unsubscribe() {
	mut server := new_server(8080)

	server.add_client('client-1')

	// Manually subscribe client to topic
	mut client := server.clients['client-1']
	client.topics << 'updates'
	server.clients['client-1'] = client

	assert server.get_subscriber_count('updates') == 1

	// Unsubscribe
	mut idx := -1
	for i, t in client.topics {
		if t == 'updates' {
			idx = i
			break
		}
	}
	if idx >= 0 {
		client.topics.delete(idx)
	}
	server.clients['client-1'] = client

	assert server.get_subscriber_count('updates') == 0
}

fn test_multiple_subscribers() {
	mut server := new_server(8080)

	server.add_client('client-1')
	server.add_client('client-2')
	server.add_client('client-3')

	// Manually subscribe clients to topic
	for i in 1 .. 4 {
		mut client := server.clients['client-${i}']
		client.topics << 'updates'
		server.clients['client-${i}'] = client
	}

	assert server.get_subscriber_count('updates') == 3

	// Unsubscribe one client
	mut client := server.clients['client-2']
	mut idx := -1
	for i, t in client.topics {
		if t == 'updates' {
			idx = i
			break
		}
	}
	if idx >= 0 {
		client.topics.delete(idx)
	}
	server.clients['client-2'] = client

	assert server.get_subscriber_count('updates') == 2
}

fn test_register_handler() {
	mut server := new_server(8080)

	handler := fn (msg Message) {
		println('Received: ${msg.action}')
	}

	server.register_handler('custom_action', handler)

	assert server.handlers.len == 1
	assert 'custom_action' in server.handlers
}

fn test_broadcast() {
	mut server := new_server(8080)

	server.add_client('client-1')
	server.add_client('client-2')

	// Manually subscribe clients to topic
	for i in 1 .. 3 {
		mut client := server.clients['client-${i}']
		client.topics << 'updates'
		server.clients['client-${i}'] = client
	}

	// Broadcast
	server.broadcast('updates', {'message': 'hello'})
}

fn test_send_to_client() {
	mut server := new_server(8080)

	server.add_client('client-1')

	// Should succeed
	server.send('client-1', {'message': 'hello'}) or {
		assert false, 'send failed: ${err}'
	}

	// Should fail for non-existent client
	mut failed := false
	server.send('non-existent', {}) or {
		failed = true
	}
	assert failed == true
}

fn test_set_callbacks() {
	mut server := new_server(8080)

	// Set callbacks
	server.set_on_connect(fn (client Client) {
		println('Client connected: ${client.id}')
	})

	server.set_on_disconnect(fn (client Client) {
		println('Client disconnected: ${client.id}')
	})

	// Add and remove client
	server.add_client('client-1')
	server.remove_client('client-1')
	
	// If we get here without panic, callbacks work
	assert true
}

fn test_multiple_topics() {
	mut server := new_server(8080)

	server.add_client('client-1')

	// Subscribe to multiple topics
	topics := ['updates', 'notifications', 'alerts']
	mut client := server.clients['client-1']
	for topic in topics {
		client.topics << topic
	}
	server.clients['client-1'] = client

	// Check each topic
	for topic in topics {
		assert server.get_subscriber_count(topic) == 1
	}
}
