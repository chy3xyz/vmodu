// solana_test.v - Unit tests for Solana adapter

module solana

fn test_new_adapter() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	assert adapter.rpc_url == 'https://api.devnet.solana.com'
	assert adapter.commitment == default_commitment
	assert adapter.is_connected == false
}

fn test_connect_disconnect() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	assert adapter.is_connected == false

	adapter.connect()!
	assert adapter.is_connected == true

	adapter.disconnect()
	assert adapter.is_connected == false
}

fn test_get_balance() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	// Should return 0 when not connected
	balance := adapter.get_balance('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH')
	assert balance == 0

	// Connect and check again
	adapter.connect()!
	balance2 := adapter.get_balance('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH')
	assert balance2 == 10 * lamports_per_sol // 10 SOL
}

fn test_sol_to_lamports() {
	assert sol_to_lamports(1.0) == 1000000000
	assert sol_to_lamports(0.5) == 500000000
	assert sol_to_lamports(2.5) == 2500000000
}

fn test_lamports_to_sol() {
	assert lamports_to_sol(1000000000) == 1.0
	assert lamports_to_sol(500000000) == 0.5
}

fn test_is_valid_pubkey() {
	// Valid pubkey (base58, 32-44 chars)
	assert is_valid_pubkey('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH') == true
	assert is_valid_pubkey('11111111111111111111111111111111') == true

	// Invalid pubkeys
	assert is_valid_pubkey('too_short') == false
	assert is_valid_pubkey('this_is_way_too_long_to_be_a_valid_solana_pubkey_12345678901234567890') == false
}

fn test_send_transaction() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	tx := Transaction{
		fee_payer:        'HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH'
		signatures:       []
		instructions:     []
		recent_blockhash: 'blockhash123'
	}

	// Should fail when not connected
	mut failed := false
	adapter.send_transaction(tx) or {
		failed = true
	}
	assert failed == true

	// Should succeed when connected
	adapter.connect()!
	signature := adapter.send_transaction(tx)!
	assert signature.len == 128 // 64 hex bytes = 128 chars
}

fn test_get_account_info() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	// Should return none when not connected
	result := adapter.get_account_info('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH')
	assert result == none

	// Should return account info when connected
	adapter.connect()!
	result2 := adapter.get_account_info('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH')
	assert result2 != none
}

fn test_get_token_accounts() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	// Should return empty when not connected
	accounts := adapter.get_token_accounts('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH')
	assert accounts.len == 0

	// Should return token accounts when connected
	adapter.connect()!
	accounts2 := adapter.get_token_accounts('HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH')
	assert accounts2.len == 2
	assert accounts2[0].decimals == 6
}

fn test_new_adapter_from_config() {
	config := SolanaConfig{
		rpc_url:    'https://mainnet.helius-rpc.com'
		commitment: 'finalized'
		ws_url:     'wss://mainnet.helius-rpc.com'
	}

	adapter := new_adapter_from_config(config)

	assert adapter.rpc_url == 'https://mainnet.helius-rpc.com'
	assert adapter.commitment == 'finalized'
	assert adapter.is_connected == false
}

fn test_simulate_transaction() {
	mut adapter := new_adapter('https://api.devnet.solana.com')

	tx := Transaction{
		fee_payer:        'HN7cABqLq46Es1jh92dQQisAq662SmxELLLsHHe4YWrH'
		signatures:       []
		instructions:     []
		recent_blockhash: 'blockhash123'
	}

	// Should fail when not connected
	mut failed := false
	adapter.simulate_transaction(tx) or {
		failed = true
	}
	assert failed == true

	// Should succeed when connected
	adapter.connect()!
	result := adapter.simulate_transaction(tx)!
	assert result.logs.len > 0
	assert result.units_consumed == 200000
}
