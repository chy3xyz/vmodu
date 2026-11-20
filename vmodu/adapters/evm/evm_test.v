// evm_test.v - Unit tests for EVM adapter

module evm

fn test_new_adapter() {
	mut adapter := new_adapter('https://ethereum-rpc.publicnode.com')

	assert adapter.rpc_url == 'https://ethereum-rpc.publicnode.com'
	assert adapter.chain_id == default_chain_id
	assert adapter.gas_limit == default_gas_limit
	assert adapter.is_connected == false
}

fn test_connect_disconnect() {
	mut adapter := new_adapter('https://ethereum-rpc.publicnode.com')

	assert adapter.is_connected == false

	adapter.connect()!
	assert adapter.is_connected == true

	adapter.disconnect()
	assert adapter.is_connected == false
}

fn test_get_balance() {
	mut adapter := new_adapter('https://ethereum-rpc.publicnode.com')

	// Should return 0 when not connected
	balance := adapter.get_balance('0x1234567890abcdef')
	assert balance == '0'

	// Connect and check again
	adapter.connect()!
	balance2 := adapter.get_balance('0x1234567890abcdef')
	assert balance2 == '1000000000000000000' // 1 ETH
}

fn test_format_address() {
	assert format_address('123abc') == '0x123abc'
	assert format_address('0x123abc') == '0x123abc'
	assert format_address('0xAbCdEf') == '0xAbCdEf'
}

fn test_is_valid_address() {
	assert is_valid_address('0x1234567890123456789012345678901234567890') == true
	assert is_valid_address('1234567890123456789012345678901234567890') == true
	assert is_valid_address('0x123') == false
	assert is_valid_address('invalid') == false
}

fn test_eth_to_wei() {
	assert eth_to_wei(1.0) == '1000000000000000000'
	assert eth_to_wei(0.5) == '500000000000000000'
	assert eth_to_wei(2.5) == '2500000000000000000'
}

fn test_wei_to_eth() {
	assert wei_to_eth('1000000000000000000') == 1.0
	assert wei_to_eth('500000000000000000') == 0.5
}

fn test_send_transaction() {
	mut adapter := new_adapter('https://ethereum-rpc.publicnode.com')

	tx := Transaction{
		from:      '0x1234567890123456789012345678901234567890'
		to:        '0x0987654321098765432109876543210987654321'
		value:     '1000000000000000000'
		gas_limit: 21000
		gas_price: 20000000000
		nonce:     0
		chain_id:  1
	}

	// Should fail when not connected
	mut failed := false
	adapter.send_transaction(tx) or {
		failed = true
	}
	assert failed == true

	// Should succeed when connected
	adapter.connect()!
	tx_hash := adapter.send_transaction(tx)!
	assert tx_hash.starts_with('0x')
	assert tx_hash.len == 66 // 0x + 64 hex chars
}

fn test_estimate_gas() {
	mut adapter := new_adapter('https://ethereum-rpc.publicnode.com')

	tx := Transaction{
		to:        '0x0987654321098765432109876543210987654321'
		value:     '1000000000000000000'
		gas_limit: 21000
	}

	// Should return 0 when not connected
	assert adapter.estimate_gas(tx) == 0

	// Should return estimated gas when connected
	adapter.connect()!
	assert adapter.estimate_gas(tx) == 21000
}

fn test_new_adapter_from_config() {
	config := EvmConfig{
		rpc_url:        'https://mainnet.infura.io/v3/key'
		chain_id:       1
		gas_limit:      5000000
		gas_price_gwei: 30.0
	}

	adapter := new_adapter_from_config(config)

	assert adapter.rpc_url == 'https://mainnet.infura.io/v3/key'
	assert adapter.chain_id == 1
	assert adapter.gas_limit == 5000000
	assert adapter.gas_price == 30000000000 // 30 gwei
}
