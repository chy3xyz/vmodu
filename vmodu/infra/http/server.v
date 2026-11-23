// server.v - HTTP Server for VModulith Runtime
// v3.1: Production-ready HTTP server with routing, middleware, and graceful shutdown

module http

import net
import net.http as net_http
import json2
import time
import sync
import rand

// HandlerFunc is the HTTP handler function type
pub type HandlerFunc = fn (Context) !Response

// Middleware is a function that wraps handlers
pub type Middleware = fn (HandlerFunc) HandlerFunc

// Context holds request context
pub struct Context {
pub:
	request     net_http.Request
	params      map[string]string
	method      string
	path        string
	start_time  i64
	request_id  string
	client_ip   string
mut:
	response Response
}

// Response represents HTTP response
pub struct Response {
pub mut:
	status_code int
	headers     map[string]string
	body        string
}

// new_response creates a new Response
pub fn new_response() Response {
	return Response{
		status_code: 200
		headers:     {
			'Content-Type': 'application/json'
		}
		body:        ''
	}
}

// json returns JSON response
pub fn (mut r Response) json(data any) {
	r.headers['Content-Type'] = 'application/json'
	r.body = json2.encode(data, escape_unicode: true)
}

// text returns text response
pub fn (mut r Response) text(data string) {
	r.headers['Content-Type'] = 'text/plain'
	r.body = data
}

// Route represents a route definition
pub struct Route {
pub:
	method  string
	path    string
	handler HandlerFunc = unsafe { nil }
}

// Server is the HTTP server
@[heap]
pub struct Server {
pub mut:
	port             int
	host             string
	read_timeout     time.Duration = 30 * time.second
	write_timeout    time.Duration = 30 * time.second
	max_body_size    i64           = 10 * 1024 * 1024
	max_connections  int           = 1024
	stop_timeout_ms  int           = 5000
	rate_limit_rps      int
	rate_limit_burst    int
	rate_limit_per_ip   bool
	ip_rate_limit_rps   int
	ip_rate_limit_burst int
	access_log          bool // structured JSON access logs to stdout
	routes              []Route
	middlewares         []Middleware
	is_running          bool
	mu                  sync.RwMutex
	requests_total      u64
	requests_active     int
	rate_limited_total  u64 // 429 responses (global + per-IP)
mut:
	listener         &net.TcpListener = unsafe { nil }
	rate_limiter     &RateLimiter     = unsafe { nil }
	ip_rate_limiter  &IpRateLimiter   = unsafe { nil }
}

// ServerConfig for server configuration
pub struct ServerConfig {
pub:
	port                int    = 8080
	host                string = '0.0.0.0'
	read_timeout        int    = 30
	write_timeout       int    = 30
	max_body_size       i64    = 10 * 1024 * 1024
	max_connections     int    = 1024
	stop_timeout_ms     int    = 5000
	rate_limit_rps      int // 0 = disabled (global)
	rate_limit_burst    int // 0 => max(1, rate_limit_rps)
	rate_limit_per_ip   bool // enable per-IP buckets
	ip_rate_limit_rps   int  // 0 => reuse rate_limit_rps when per-IP on
	ip_rate_limit_burst int  // 0 => reuse rate_limit_burst / rps
	access_log          bool = true // JSON access log lines
}

// new_server creates a new HTTP server
pub fn new_server(config ServerConfig) &Server {
	burst := if config.rate_limit_burst > 0 {
		config.rate_limit_burst
	} else if config.rate_limit_rps > 0 {
		config.rate_limit_rps
	} else {
		0
	}
	ip_rps := if config.ip_rate_limit_rps > 0 {
		config.ip_rate_limit_rps
	} else if config.rate_limit_per_ip {
		config.rate_limit_rps
	} else {
		0
	}
	ip_burst := if config.ip_rate_limit_burst > 0 {
		config.ip_rate_limit_burst
	} else if ip_rps > 0 {
		if burst > 0 { burst } else { ip_rps }
	} else {
		0
	}
	return &Server{
		port:               config.port
		host:               config.host
		read_timeout:       config.read_timeout * time.second
		write_timeout:      config.write_timeout * time.second
		max_body_size:      config.max_body_size
		max_connections:    config.max_connections
		stop_timeout_ms:    config.stop_timeout_ms
		rate_limit_rps:     config.rate_limit_rps
		rate_limit_burst:   burst
		rate_limit_per_ip:  config.rate_limit_per_ip
		ip_rate_limit_rps:  ip_rps
		ip_rate_limit_burst: ip_burst
		access_log:         config.access_log
		routes:             []
		middlewares:        []
		is_running:         false
		rate_limiter:       new_rate_limiter(config.rate_limit_rps, burst)
		ip_rate_limiter:    new_ip_rate_limiter(ip_rps, ip_burst, 10000)
	}
}

fn new_request_id() string {
	return '${time.now().unix_milli()}_${rand.intn(1_000_000) or { 0 }}'
}

// GET registers a GET route
pub fn (mut s Server) get(path string, handler HandlerFunc) {
	s.add_route('GET', path, handler)
}

// POST registers a POST route
pub fn (mut s Server) post(path string, handler HandlerFunc) {
	s.add_route('POST', path, handler)
}

// add_route adds a route
pub fn (mut s Server) add_route(method string, path string, handler HandlerFunc) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.routes << Route{
		method:  method.to_upper()
		path:    path
		handler: handler
	}
}

// use adds middleware
pub fn (mut s Server) use(mw Middleware) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.middlewares << mw
}

// start starts the server (listens and spawns accept loop)
pub fn (mut s Server) start() ! {
	if s.is_running {
		return error('server already running')
	}

	listen_addr := '${s.host}:${s.port}'
	s.listener = net.listen_tcp(.ip, listen_addr)!
	bound := s.listener.addr()!
	s.port = int(bound.port()!)
	s.is_running = true

	println('[HTTP] Server listening on http://${s.host}:${s.port}')
	spawn s.accept_loop()
}

// stop stops the server: close listener, then wait for in-flight requests or timeout
pub fn (mut s Server) stop() ! {
	s.mu.lock()
	s.is_running = false
	timeout_ms := s.stop_timeout_ms
	s.mu.unlock()

	if !isnil(s.listener) {
		s.listener.close() or {}
		s.listener = unsafe { nil }
	}

	deadline := time.now().unix_milli() + i64(timeout_ms)
	for {
		s.mu.rlock()
		active := s.requests_active
		s.mu.runlock()
		if active == 0 {
			break
		}
		if time.now().unix_milli() >= deadline {
			break
		}
		time.sleep(10 * time.millisecond)
	}
	println('[HTTP] Server stopped')
}

// is_running returns server status
pub fn (s &Server) is_running() bool {
	return s.is_running
}

// get_stats returns server statistics
pub fn (s &Server) get_stats() ServerStats {
	s.mu.rlock()
	defer { s.mu.runlock() }
	return ServerStats{
		requests_total:     s.requests_total
		requests_active:    s.requests_active
		rate_limited_total: s.rate_limited_total
		is_running:         s.is_running
	}
}

// ServerStats contains server metrics
pub struct ServerStats {
pub:
	requests_total     u64
	requests_active    int
	rate_limited_total u64
	is_running         bool
}

fn (mut s Server) accept_loop() {
	for {
		s.mu.rlock()
		running := s.is_running
		s.mu.runlock()
		if !running {
			break
		}
		if isnil(s.listener) {
			break
		}

		mut conn := s.listener.accept() or {
			s.mu.rlock()
			still := s.is_running
			s.mu.runlock()
			if still {
				eprintln('[HTTP] Accept error: ${err}')
				time.sleep(50 * time.millisecond)
			}
			continue
		}

		s.mu.rlock()
		over_limit := s.requests_active >= s.max_connections
		s.mu.runlock()
		if over_limit {
			s.write_raw(mut conn, 503, 'text/plain', 'Service Unavailable')
			conn.close() or {}
			continue
		}

		spawn s.handle_connection(mut conn)
	}
}

fn (mut s Server) handle_connection(mut conn net.TcpConn) {
	defer {
		conn.close() or {}
	}

	conn.set_read_timeout(s.read_timeout)
	conn.set_write_timeout(s.write_timeout)

	s.mu.lock()
	s.requests_active++
	s.requests_total++
	s.mu.unlock()
	defer {
		s.mu.lock()
		s.requests_active--
		s.mu.unlock()
	}

	req_line, headers, body := s.read_http_request(mut conn) or {
		s.write_raw(mut conn, 400, 'text/plain', 'Bad Request')
		return
	}

	parts := req_line.split(' ')
	if parts.len < 2 {
		s.write_raw(mut conn, 400, 'text/plain', 'Bad Request')
		return
	}

	method := parts[0].to_upper()
	raw_target := parts[1]
	path := normalize_path(raw_target)

	peer := conn.peer_ip() or { 'unknown' }

	req_id := headers['x-request-id'] or { '' }
	request_id := if req_id.len > 0 { req_id } else { new_request_id() }
	t0 := time.now().unix_milli()

	if s.rate_limit_per_ip && s.ip_rate_limit_rps > 0 && !isnil(s.ip_rate_limiter) {
		mut ip_lim := s.ip_rate_limiter
		if !ip_lim.allow(peer) {
			s.mu.lock()
			s.rate_limited_total++
			s.mu.unlock()
			s.log_access(peer, method, path, request_id, 429, t0)
			s.write_raw(mut conn, 429, 'text/plain', 'Too Many Requests')
			return
		}
	}

	if s.rate_limit_rps > 0 && !isnil(s.rate_limiter) {
		mut lim := s.rate_limiter
		if !lim.allow() {
			s.mu.lock()
			s.rate_limited_total++
			s.mu.unlock()
			s.log_access(peer, method, path, request_id, 429, t0)
			s.write_raw(mut conn, 429, 'text/plain', 'Too Many Requests')
			return
		}
	}

	route, params := s.find_route(method, path)
	if route.handler == unsafe { nil } {
		s.log_access(peer, method, path, request_id, 404, time.now().unix_milli())
		s.write_raw(mut conn, 404, 'application/json', '{"error":"not found"}')
		return
	}

	start_ms := time.now().unix_milli()
	req := net_http.new_request(net_http.method_from_str(method), path, body)
	ctx := Context{
		request:    req
		params:     params
		method:     method
		path:       path
		start_time: start_ms
		request_id: request_id
		client_ip:  peer
		response:   new_response()
	}

	handler := s.wrap_middlewares(route.handler)
	mut resp := handler(ctx) or {
		s.log_access(peer, method, path, request_id, 500, start_ms)
		s.write_raw(mut conn, 500, 'text/plain', 'Internal Server Error')
		return
	}
	resp.headers['X-Request-ID'] = request_id
	s.log_access(peer, method, path, request_id, resp.status_code, start_ms)
	s.write_response(mut conn, resp)
}

fn (s &Server) log_access(ip string, method string, path string, request_id string, status int, start_ms i64) {
	if !s.access_log {
		return
	}
	dur := time.now().unix_milli() - start_ms
	// Structured single-line JSON for log aggregators
	println('{"msg":"access","request_id":"${request_id}","ip":"${ip}","method":"${method}","path":"${path}","status":${status},"duration_ms":${dur}}')
}

fn (s &Server) wrap_middlewares(handler HandlerFunc) HandlerFunc {
	s.mu.rlock()
	mws := s.middlewares.clone()
	s.mu.runlock()

	mut h := handler
	// Last registered middleware is outermost (applied last in reverse wrap)
	for i := mws.len - 1; i >= 0; i-- {
		h = mws[i](h)
	}
	return h
}

fn (s &Server) find_route(method string, path string) (Route, map[string]string) {
	s.mu.rlock()
	routes := s.routes.clone()
	s.mu.runlock()

	mut empty := Route{}
	for route in routes {
		if route.method != method {
			continue
		}
		if params := match_path(route.path, path) {
			return route, params
		}
	}
	return empty, map[string]string{}
}

fn match_path(pattern string, path string) ?map[string]string {
	if pattern == path {
		return map[string]string{}
	}

	p_parts := pattern.trim('/').split('/')
	t_parts := path.trim('/').split('/')
	if pattern == '/' && path == '/' {
		return map[string]string{}
	}
	if p_parts.len != t_parts.len {
		return none
	}
	if pattern != '/' && p_parts.len == 1 && p_parts[0] == '' && path != '/' {
		return none
	}

	mut params := map[string]string{}
	for i, part in p_parts {
		if part.starts_with(':') {
			params[part[1..]] = t_parts[i]
			continue
		}
		if part != t_parts[i] {
			return none
		}
	}
	return params
}

fn normalize_path(target string) string {
	mut path := target
	if path.contains('?') {
		path = path.all_before('?')
	}
	if path == '' {
		return '/'
	}
	return path
}

fn (s &Server) read_http_request(mut conn net.TcpConn) !(string, map[string]string, string) {
	mut buf := []u8{len: 4096}
	mut raw := []u8{}
	mut header_end := -1

	for raw.len < 65536 {
		n := conn.read(mut buf) or { return error('read failed: ${err}') }
		if n <= 0 {
			break
		}
		raw << buf[..n]
		header_end = index_of_header_end(raw)
		if header_end >= 0 {
			break
		}
	}
	if header_end < 0 {
		return error('incomplete headers')
	}

	head := raw[..header_end].bytestr()
	lines := head.split('\r\n')
	if lines.len == 0 || lines[0].len == 0 {
		return error('empty request')
	}

	mut headers := map[string]string{}
	for i := 1; i < lines.len; i++ {
		line := lines[i]
		if line.len == 0 {
			continue
		}
		colon := line.index(':') or { continue }
		key := line[..colon].trim_space().to_lower()
		val := line[colon + 1..].trim_space()
		headers[key] = val
	}

	mut body := ''
	rest := unsafe { raw[header_end + 4..] }
	content_length := headers['content-length'] or { '0' }.int()
	if content_length < 0 || content_length > int(s.max_body_size) {
		return error('body too large')
	}
	if content_length > 0 {
		mut body_buf := rest.clone()
		for body_buf.len < content_length {
			n := conn.read(mut buf) or { break }
			if n <= 0 {
				break
			}
			body_buf << buf[..n]
		}
		if body_buf.len < content_length {
			return error('incomplete body')
		}
		body = unsafe { body_buf[..content_length] }.bytestr()
	}

	return lines[0], headers, body
}

fn index_of_header_end(data []u8) int {
	for i := 0; i + 3 < data.len; i++ {
		if data[i] == `\r` && data[i + 1] == `\n` && data[i + 2] == `\r` && data[i + 3] == `\n` {
			return i
		}
	}
	return -1
}

fn (s &Server) write_response(mut conn net.TcpConn, resp Response) {
	status := if resp.status_code == 0 { 200 } else { resp.status_code }
	mut headers := resp.headers.clone()
	if 'Content-Type' !in headers && 'content-type' !in headers {
		headers['Content-Type'] = 'text/plain'
	}
	headers['Content-Length'] = resp.body.len.str()
	headers['Connection'] = 'close'

	mut out := 'HTTP/1.1 ${status} ${status_text(status)}\r\n'
	for k, v in headers {
		out += '${k}: ${v}\r\n'
	}
	out += '\r\n'
	out += resp.body
	conn.write_string(out) or {}
}

fn (s &Server) write_raw(mut conn net.TcpConn, status int, content_type string, body string) {
	mut resp := new_response()
	resp.status_code = status
	resp.headers = {
		'Content-Type': content_type
	}
	resp.body = body
	s.write_response(mut conn, resp)
}

fn status_text(code int) string {
	return match code {
		200 { 'OK' }
		201 { 'Created' }
		204 { 'No Content' }
		400 { 'Bad Request' }
		401 { 'Unauthorized' }
		403 { 'Forbidden' }
		404 { 'Not Found' }
		405 { 'Method Not Allowed' }
		429 { 'Too Many Requests' }
		500 { 'Internal Server Error' }
		502 { 'Bad Gateway' }
		503 { 'Service Unavailable' }
		else { 'OK' }
	}
}
