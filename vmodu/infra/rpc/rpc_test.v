// rpc_test.v - Unit tests for RPC module

module rpc

import vmodu.intent

fn test_new_gateway() {
	gateway := new_gateway()

	assert gateway.http_port == default_http_port
	assert gateway.grpc_port == default_grpc_port
	assert gateway.is_running == false
	assert gateway.handlers.len == 0
	assert gateway.middlewares.len == 0
}

fn test_with_ports() {
	mut gateway := new_gateway()
	gateway.with_ports(3000, 5000)

	assert gateway.http_port == 3000
	assert gateway.grpc_port == 5000
}

fn test_register_handler() {
	mut gateway := new_gateway()

	handler := fn (i intent.Intent) RpcResponse {
		return RpcResponse{
			success: true
			data:    'ok'
			err:     none
			code:    200
		}
	}

	gateway.register_handler('test.method', handler)

	assert gateway.handlers.len == 1
	assert 'test.method' in gateway.handlers
}

fn test_add_middleware() {
	mut gateway := new_gateway()

	mw := fn (req RpcRequest) RpcRequest {
		return req
	}

	gateway.add_middleware(mw)

	assert gateway.middlewares.len == 1
}

fn test_start_stop() {
	mut gateway := new_gateway()

	assert gateway.is_running == false

	gateway.start()!
	assert gateway.is_running == true

	// Should fail when already running
	mut failed := false
	gateway.start() or {
		failed = true
	}
	assert failed == true

	gateway.stop()
	assert gateway.is_running == false
}

fn test_handle_request() {
	mut gateway := new_gateway()

	// Register a handler
	gateway.register_handler('test.echo', fn (i intent.Intent) RpcResponse {
		return RpcResponse{
			success: true
			data:    i.get_param('message')
			err:     none
			code:    200
		}
	})

	// Test successful request
	req := RpcRequest{
		id:      '1'
		method:  'test.echo'
		params:  {'message': 'hello'}
		headers: {}
	}

	response := gateway.handle_request(req)
	assert response.success == true
	assert response.data == 'hello'
	assert response.code == 200

	// Test unknown method
	req2 := RpcRequest{
		id:      '2'
		method:  'unknown.method'
		params:  {}
		headers: {}
	}

	response2 := gateway.handle_request(req2)
	assert response2.success == false
	assert response2.code == 404
}

fn test_logging_middleware() {
	mw := logging_middleware()

	req := RpcRequest{
		id:      '1'
		method:  'test'
		params:  {}
		headers: {}
	}

	result := mw(req)
	assert result.id == '1'
	assert result.method == 'test'
}

fn test_auth_middleware() {
	mw := auth_middleware('secret-token')

	// Request with valid token
	req1 := RpcRequest{
		id:      '1'
		method:  'test'
		params:  {}
		headers: {'authorization': 'secret-token'}
	}
	result1 := mw(req1)
	assert result1.id == '1'

	// Request with invalid token
	req2 := RpcRequest{
		id:      '2'
		method:  'test'
		params:  {}
		headers: {'authorization': 'wrong-token'}
	}
	result2 := mw(req2)
	assert result2.id == '2'
}

fn test_format_json_response() {
	response := JsonResponse{
		jsonrpc: '2.0'
		id:      1
		result:  'success'
		err:     none
	}

	json_str := format_json_response(response)
	assert json_str.contains('"jsonrpc":"2.0"')
	assert json_str.contains('"id":1')
	assert json_str.contains('"result":"success"')
}

fn test_get_stats() {
	gateway := new_gateway()
	stats := gateway.get_stats()

	assert stats.total_requests == 0
	assert stats.success_count == 0
	assert stats.error_count == 0
}
