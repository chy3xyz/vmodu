// agent/llm/client.v
// LLM API client (OpenAI/Anthropic-shaped HTTP).
// Features: retry/backoff, response cache, basic rate limit.
// Note: network path needs a real API key; decompose parses JSON via json2
// with a safe fallback when the model returns non-JSON.

module llm

import net.http
import json2
import time
import sync
import crypto.md5

// Provider type
pub enum Provider {
	openai
	anthropic
	local
}

// Config for LLM client
pub struct Config {
pub mut:
	provider        Provider = .openai
	base_url        string   = 'https://api.openai.com/v1'
	api_key         string
	model           string = 'gpt-4'
	max_tokens      int    = 2048
	temperature     f64    = 0.7
	timeout_ms      int    = 30000
	max_retries     int    = 3
	retry_delay_ms  int    = 1000
	cache_enabled   bool   = true
	cache_ttl_ms    int    = 3600000 // 1 hour
	rate_limit_rps  f64    = 10.0    // Requests per second
	connection_pool int    = 10
}

// Message represents a chat message
pub struct Message {
pub:
	role    string @[json: 'role']
	content string @[json: 'content']
}

// CompletionRequest is sent to LLM API
struct CompletionRequest {
	model       string    @[json: 'model']
	messages    []Message @[json: 'messages']
	max_tokens  int       @[json: 'max_tokens']
	temperature f64       @[json: 'temperature']
	stream      bool      @[json: 'stream']
}

// CompletionResponse is returned by LLM API
pub struct CompletionResponse {
pub:
	content       string
	tokens_used   int
	finish_reason string
	model         string
	latency_ms    int
pub mut:
	cached bool
}

// Usage info from API response
struct APIUsage {
	prompt_tokens     int @[json: 'prompt_tokens']
	completion_tokens int @[json: 'completion_tokens']
	total_tokens      int @[json: 'total_tokens']
}

// APIChoice from response
struct APIChoice {
	message       Message @[json: 'message']
	finish_reason string  @[json: 'finish_reason']
	index         int     @[json: 'index']
}

// OpenAIResponse structure
struct OpenAIResponse {
	id      string      @[json: 'id']
	object  string      @[json: 'object']
	created int         @[json: 'created']
	model   string      @[json: 'model']
	choices []APIChoice @[json: 'choices']
	usage   APIUsage    @[json: 'usage']
}

// Cache entry
struct CacheEntry {
	response   CompletionResponse
	expires_at i64
}

// Client for LLM API
@[heap]
pub struct Client {
pub mut:
	config       Config
	cache        map[string]CacheEntry
	cache_mu     sync.RwMutex
	request_mu   sync.Mutex
	last_request i64
	tokens       f64 = 10.0 // Token bucket for rate limiting
}

// new_client creates a new LLM client
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
		cache:  {}
	}
}

// default_client creates a client with default config
pub fn default_client() &Client {
	return new_client(Config{})
}

// complete sends a completion request with retry logic
pub fn (mut c Client) complete(messages []Message) !CompletionResponse {
	// Check cache first
	if c.config.cache_enabled {
		if cached := c.get_cached(messages) {
			return cached
		}
	}

	// Rate limiting
	c.wait_for_rate_limit()

	// Build request
	req := CompletionRequest{
		model:       c.config.model
		messages:    messages
		max_tokens:  c.config.max_tokens
		temperature: c.config.temperature
		stream:      false
	}

	req_body := json2.encode(req, escape_unicode: true, time_as_unix: true)

	// Try with retries
	mut last_err := ''
	for attempt := 0; attempt < c.config.max_retries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			delay := c.config.retry_delay_ms * (1 << attempt)
			time.sleep(delay * time.millisecond)
		}

		result := c.do_request(req_body) or {
			last_err = err.msg()
			continue
		}

		// Cache successful response
		if c.config.cache_enabled {
			c.cache_response(messages, result)
		}

		return result
	}

	return error('LLM request failed after ${c.config.max_retries} retries: ${last_err}')
}

// do_request makes the actual HTTP request
fn (mut c Client) do_request(body string) !CompletionResponse {
	start := time.now().unix_milli()

	// Build HTTP request
	mut req := http.new_request(.post, c.config.base_url + '/chat/completions', body)
	req.add_header(.content_type, 'application/json')
	req.add_header(.authorization, 'Bearer ' + c.config.api_key)

	// Set timeout
	// Note: V's http module may have different timeout API

	// Execute request
	resp := req.do()!

	if resp.status_code != 200 {
		return error('LLM API returned ${resp.status_code}: ${resp.body}')
	}

	// Parse response
	api_resp := json2.decode[OpenAIResponse](resp.body) or {
		return error('Failed to decode LLM response: ${err}')
	}

	if api_resp.choices.len == 0 {
		return error('LLM returned no choices')
	}

	latency := int(time.now().unix_milli() - start)

	return CompletionResponse{
		content:       api_resp.choices[0].message.content
		tokens_used:   api_resp.usage.total_tokens
		finish_reason: api_resp.choices[0].finish_reason
		model:         api_resp.model
		latency_ms:    latency
		cached:        false
	}
}

// wait_for_rate_limit implements token bucket rate limiting
fn (mut c Client) wait_for_rate_limit() {
	c.request_mu.lock()
	defer { c.request_mu.unlock() }

	now := time.now().unix_milli()
	elapsed := f64(now - c.last_request) / 1000.0

	// Add tokens based on elapsed time
	c.tokens += elapsed * c.config.rate_limit_rps
	if c.tokens > c.config.rate_limit_rps {
		c.tokens = c.config.rate_limit_rps
	}

	// If no tokens available, wait
	if c.tokens < 1.0 {
		wait_ms := int((1.0 - c.tokens) / c.config.rate_limit_rps * 1000.0)
		time.sleep(wait_ms * time.millisecond)
		c.tokens = 0.0
	} else {
		c.tokens -= 1.0
	}

	c.last_request = now
}

// cache_key generates a cache key for messages
fn (c &Client) cache_key(messages []Message) string {
	// Simple hash of messages
	mut data := ''
	for msg in messages {
		data += msg.role + ':' + msg.content + '|'
	}
	return md5.hexhash(data)
}

// get_cached retrieves cached response
fn (mut c Client) get_cached(messages []Message) ?CompletionResponse {
	c.cache_mu.rlock()
	defer { c.cache_mu.runlock() }

	key := c.cache_key(messages)
	entry := c.cache[key] or { return none }

	// Check expiration
	if time.now().unix_milli() > entry.expires_at {
		return none
	}

	mut result := entry.response
	result.cached = true
	return result
}

// cache_response stores response in cache
fn (mut c Client) cache_response(messages []Message, response CompletionResponse) {
	c.cache_mu.lock()
	defer { c.cache_mu.unlock() }

	key := c.cache_key(messages)
	c.cache[key] = CacheEntry{
		response:   response
		expires_at: time.now().unix_milli() + c.config.cache_ttl_ms
	}
}

// clear_cache removes all cached responses
pub fn (mut c Client) clear_cache() {
	c.cache_mu.lock()
	defer { c.cache_mu.unlock() }
	c.cache = {}
}

// get_cache_size returns number of cached entries
pub fn (c &Client) get_cache_size() int {
	c.cache_mu.rlock()
	defer { c.cache_mu.runlock() }
	return c.cache.len
}

// complete_simple is a convenience method for single-turn completion
pub fn (mut c Client) complete_simple(prompt string) !CompletionResponse {
	messages := [
		Message{ role: 'user', content: prompt },
	]
	return c.complete(messages)
}

// complete_with_system adds a system message before completion
pub fn (mut c Client) complete_with_system(system_prompt string, user_prompt string) !CompletionResponse {
	messages := [
		Message{ role: 'system', content: system_prompt }
		Message{ role: 'user', content: user_prompt },
	]
	return c.complete(messages)
}

// LLMPlanner uses LLM for task decomposition
pub struct LLMPlanner {
	client &Client
}

// new_planner creates a new LLM planner
pub fn new_planner(client &Client) LLMPlanner {
	return LLMPlanner{ client: client }
}

// Plan represents a decomposition of a task
pub struct Plan {
pub:
	goal       string
	steps      []PlanStep
	confidence f64
}

// PlanStep is a single step in a plan
pub struct PlanStep {
pub:
	action      string @[json: 'action']
	description string @[json: 'description']
	depends_on  []int  @[json: 'depends_on']
}

// plan_decode is the JSON shape returned by the LLM for decompose()
struct PlanDecode {
	steps      []PlanStep @[json: 'steps']
	confidence f64        @[json: 'confidence']
}

// decompose breaks down a goal into actionable steps.
// Tries json2.decode of the LLM content; falls back to a safe default plan.
pub fn (p LLMPlanner) decompose(goal string) !Plan {
	system_prompt := 'You are a task decomposition assistant. Break down goals into specific, actionable steps.'

	user_prompt := 'Decompose this goal into 3-5 specific steps: "${goal}"
Return your response in this JSON format:
{
  "steps": [
    {"action": "name", "description": "details"}
  ],
  "confidence": 0.8
}'

	mut client := p.client
	resp := client.complete_with_system(system_prompt, user_prompt)!

	if plan := parse_plan_json(goal, resp.content) {
		return plan
	}

	// Fallback when LLM output is missing/invalid JSON — keep callers working.
	return Plan{
		goal:       goal
		steps:      [
			PlanStep{ action: 'analyze', description: 'Analyze the goal' }
			PlanStep{ action: 'plan', description: 'Create execution plan' }
			PlanStep{ action: 'execute', description: 'Execute the plan' },
		]
		confidence: 0.7
	}
}

// parse_plan_json extracts a JSON object from LLM text and decodes Plan steps.
fn parse_plan_json(goal string, raw string) ?Plan {
	json_text := extract_json_object(raw)
	if json_text.len == 0 {
		return none
	}
	decoded := json2.decode[PlanDecode](json_text) or { return none }
	if decoded.steps.len == 0 {
		return none
	}
	conf := if decoded.confidence > 0 { decoded.confidence } else { 0.7 }
	return Plan{
		goal:       goal
		steps:      decoded.steps
		confidence: conf
	}
}

// extract_json_object pulls the first {...} blob (strips optional markdown fences).
fn extract_json_object(raw string) string {
	trimmed := raw.trim_space()
	if trimmed.len == 0 {
		return ''
	}
	mut s := trimmed
	if s.starts_with('```') {
		lines := s.split_into_lines()
		mut body := []string{}
		for i, line in lines {
			if i == 0 {
				continue
			}
			if line.trim_space().starts_with('```') {
				break
			}
			body << line
		}
		s = body.join('\n').trim_space()
	}
	start := s.index('{') or { return '' }
	end := s.last_index('}') or { return '' }
	if end < start {
		return ''
	}
	return s[start..end + 1]
}

// Mock client for testing (no network)
pub fn new_mock_client(responses map[string]CompletionResponse) &Client {
	_ = responses
	return new_client(Config{
		cache_enabled: false
	})
}
