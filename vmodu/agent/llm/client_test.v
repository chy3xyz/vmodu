// client_test.v - LLM client unit tests (no network)

module llm

import time

fn test_extract_json_object() {
	plain := '{"steps":[],"confidence":0.9}'
	assert extract_json_object(plain) == plain

	fenced := '```json\n{"steps":[{"action":"a","description":"d"}],"confidence":0.8}\n```'
	got := extract_json_object(fenced)
	assert got.contains('"action"')
	assert got.contains('"a"')

	assert extract_json_object('no json here') == ''
}

fn test_parse_plan_json() {
	raw := '{"steps":[{"action":"fetch","description":"get data"}],"confidence":0.91}'
	plan := parse_plan_json('goal-x', raw) or {
		assert false, 'expected parse success'
		return
	}
	assert plan.goal == 'goal-x'
	assert plan.steps.len == 1
	assert plan.steps[0].action == 'fetch'
	assert plan.confidence == 0.91

	if _ := parse_plan_json('g', 'not-json') {
		assert false, 'expected none for invalid json'
	}
}

fn test_cache_key_generation() {
	c := default_client()
	msgs1 := [Message{ role: 'user', content: 'hello' }]
	msgs2 := [Message{ role: 'user', content: 'hello' }]
	msgs3 := [Message{ role: 'user', content: 'world' }]
	assert c.cache_key(msgs1) == c.cache_key(msgs2)
	assert c.cache_key(msgs1) != c.cache_key(msgs3)
}

fn test_cache_operations() {
	mut c := new_client(Config{
		cache_enabled: true
		cache_ttl_ms:  1000
	})
	msgs := [Message{ role: 'user', content: 'test' }]
	resp := CompletionResponse{
		content:     'test response'
		tokens_used: 10
	}
	c.cache_response(msgs, resp)
	assert c.get_cache_size() == 1
	cached := c.get_cached(msgs) or {
		assert false, 'should have found cached response'
		return
	}
	assert cached.content == resp.content
	assert cached.cached == true
	c.clear_cache()
	assert c.get_cache_size() == 0
}

fn test_rate_limiting() {
	mut c := new_client(Config{
		rate_limit_rps: 100.0
	})
	start := time.now().unix_milli()
	c.wait_for_rate_limit()
	elapsed := time.now().unix_milli() - start
	assert elapsed < 10
}
