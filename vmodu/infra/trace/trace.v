// infra/trace/trace.v
// Distributed tracing implementation
// Features:
// - Span creation and nesting
// - Context propagation
// - Trace/Span IDs
// - Baggage (key-value pairs propagated across services)
// - Export to various backends (console, file, HTTP)

module trace

import time
import json2
import sync
import rand

// TraceID uniquely identifies a trace
pub type TraceID = string

// SpanID uniquely identifies a span within a trace
pub type SpanID = string

// generate_id generates a new random ID
fn generate_id() string {
	return rand.hex(16)
}

// Span represents a single operation within a trace
pub struct Span {
pub mut:
	trace_id    TraceID
	span_id     SpanID
	parent_id   SpanID
	name        string
	start_time  i64
	end_time    i64
	duration_ms i64
	attributes  map[string]string
	events      []SpanEvent
	status      SpanStatus
	span_kind   SpanKind
}

// SpanKind describes the relationship between span and parent
pub enum SpanKind {
	internal // Default
	server   // Server-side operation
	client   // Client-side operation
	producer // Message producer
	consumer // Message consumer
}

// SpanStatus represents operation status
pub enum SpanStatus {
	unset
	ok
	error
}

// SpanEvent is an event within a span
pub struct SpanEvent {
pub:
	time       i64
	name       string
	attributes map[string]string
}

// Tracer creates spans
pub struct Tracer {
pub mut:
	service_name string
	exporter     Exporter
	mu           sync.Mutex
}

// new_tracer creates a new tracer
pub fn new_tracer(service_name string, exporter Exporter) &Tracer {
	return &Tracer{
		service_name: service_name
		exporter:     exporter
	}
}

// start_span begins a new span
pub fn (t &Tracer) start_span(name string, opts SpanOptions) &Span {
	mut span := &Span{
		trace_id:   if opts.trace_id != '' { opts.trace_id } else { generate_id() }
		span_id:    generate_id()
		parent_id:  opts.parent_id
		name:       name
		start_time: time.now().unix_milli()
		attributes: {}
		events:     []
		status:     .unset
		span_kind:  opts.kind
	}

	// Copy attributes
	for k, v in opts.attributes {
		span.attributes[k] = v
	}

	return span
}

// SpanOptions for span creation
pub struct SpanOptions {
pub mut:
	trace_id   TraceID
	parent_id  SpanID
	attributes map[string]string
	kind       SpanKind = .internal
}

// end completes a span
pub fn (mut s Span) end() {
	s.end_time = time.now().unix_milli()
	s.duration_ms = s.end_time - s.start_time
}

// set_attribute adds an attribute
pub fn (mut s Span) set_attribute(key string, value string) {
	s.attributes[key] = value
}

// set_error marks span as error
pub fn (mut s Span) set_error() {
	s.status = .error
}

// set_ok marks span as successful
pub fn (mut s Span) set_ok() {
	s.status = .ok
}

// add_event adds an event
pub fn (mut s Span) add_event(name string, attrs map[string]string) {
	s.events << SpanEvent{
		time:       time.now().unix_milli()
		name:       name
		attributes: attrs.clone()
	}
}

// Context carries trace context across operations
pub struct Context {
pub mut:
	trace_id TraceID
	span_id  SpanID
	baggage  map[string]string
}

// new_context creates a context from a span
pub fn (s &Span) context() Context {
	return Context{
		trace_id: s.trace_id
		span_id:  s.span_id
		baggage:  {}
	}
}

// with_span creates a child span from context
pub fn (t &Tracer) with_span(name string, ctx Context) &Span {
	return t.start_span(name, SpanOptions{
		trace_id:  ctx.trace_id
		parent_id: ctx.span_id
	})
}

// set_baggage adds baggage to context
pub fn (mut ctx Context) set_baggage(key string, value string) {
	ctx.baggage[key] = value
}

// get_baggage retrieves baggage
pub fn (ctx &Context) get_baggage(key string) string {
	return ctx.baggage[key] or { '' }
}

// Exporter exports spans
pub interface Exporter {
	export(span &Span) !
	shutdown() !
}

// ConsoleExporter prints spans to console
pub struct ConsoleExporter {
pub mut:
	pretty bool
}

// new_console_exporter creates a console exporter
pub fn new_console_exporter(pretty bool) &ConsoleExporter {
	return &ConsoleExporter{ pretty: pretty }
}

pub fn (e &ConsoleExporter) export(span &Span) ! {
	if e.pretty {
		println('--- SPAN ---')
		println('Trace:  ${span.trace_id}')
		println('Span:   ${span.span_id}')
		println('Parent: ${span.parent_id}')
		println('Name:   ${span.name}')
		println('Start:  ${span.start_time}')
		println('End:    ${span.end_time}')
		println('Duration: ${span.duration_ms}ms')
		println('Status: ${span.status}')
		if span.attributes.len > 0 {
			println('Attributes:')
			for k, v in span.attributes {
				println('  ${k}: ${v}')
			}
		}
		println('---')
	} else {
		json_str := json2.encode(span, escape_unicode: true, time_as_unix: true)
		println(json_str)
	}
}

pub fn (e &ConsoleExporter) shutdown() ! {}

// InMemoryExporter stores spans in memory for testing
pub struct InMemoryExporter {
pub mut:
	spans []Span
	mu    sync.Mutex
}

// new_in_memory_exporter creates an in-memory exporter
pub fn new_in_memory_exporter() &InMemoryExporter {
	return &InMemoryExporter{ spans: [] }
}

pub fn (e &InMemoryExporter) export(span &Span) ! {
	e.mu.lock()
	defer {
		e.mu.unlock()
	}
	unsafe {
		e.spans << *span
	}
}

pub fn (e &InMemoryExporter) shutdown() ! {}

// get_spans returns all captured spans
pub fn (e &InMemoryExporter) get_spans() []Span {
	e.mu.lock()
	defer {
		e.mu.unlock()
	}
	return e.spans.clone()
}

// clear removes all spans
pub fn (e &InMemoryExporter) clear() {
	e.mu.lock()
	defer {
		e.mu.unlock()
	}
	unsafe {
		e.spans = []
	}
}

// BatchExporter buffers spans before exporting
pub struct BatchExporter {
pub mut:
	exporter          Exporter
	batch_size        int
	flush_interval_ms int
	buffer            []Span
	mu                sync.Mutex
	stop_flush        chan bool
}

// new_batch_exporter creates a batching exporter
pub fn new_batch_exporter(exporter Exporter, batch_size int, flush_interval_ms int) &BatchExporter {
	be := &BatchExporter{
		exporter:          exporter
		batch_size:        batch_size
		flush_interval_ms: flush_interval_ms
		buffer:            []
		stop_flush:        chan bool{}
	}

	// Start flush loop
	spawn be.flush_loop()

	return be
}

pub fn (mut be BatchExporter) export(span &Span) ! {
	be.mu.lock()
	defer { be.mu.unlock() }

	be.buffer << *span

	if be.buffer.len >= be.batch_size {
		be.flush() or {
			// Log error but don't fail
			eprintln('Flush error: ${err}')
		}
	}
}

fn (mut be BatchExporter) flush() ! {
	if be.buffer.len == 0 {
		return
	}

	// Export all buffered spans
	for span in be.buffer {
		be.exporter.export(&span) or {
			eprintln('Export error: ${err}')
		}
	}

	be.buffer = []
}

fn (mut be BatchExporter) flush_loop() {
	for {
		select {
			_ := <-be.stop_flush {
				be.flush() or {}
				return
			}
			be.flush_interval_ms * time.millisecond {
				be.mu.lock()
				be.flush() or {}
				be.mu.unlock()
			}
		}
	}
}

pub fn (mut be BatchExporter) shutdown() ! {
	be.stop_flush <- true
	be.exporter.shutdown()!
}


// NoopExporter discards spans (default when tracing is off).
pub struct NoopExporter {}

pub fn new_noop_exporter() &NoopExporter {
	return &NoopExporter{}
}

pub fn (e &NoopExporter) export(_ &Span) ! {}

pub fn (e &NoopExporter) shutdown() ! {}

// finish ends a span and exports it through the tracer's exporter.
pub fn (t &Tracer) finish(mut s Span) {
	s.end()
	t.exporter.export(s) or {
		eprintln('[trace] export failed: ${err}')
	}
}

// Timing helper for string operations
pub fn trace_string_operation(tracer &Tracer, name string, op fn () !string) !string {
	mut span := tracer.start_span(name, SpanOptions{
		kind: .internal
	})

	result := op() or {
		span.set_error()
		span.set_attribute('error', err.msg())
		tracer.finish(mut span)
		return err
	}

	span.set_ok()
	tracer.finish(mut span)
	return result
}
