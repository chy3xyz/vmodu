module trace

fn test_span_creation_and_finish() {
	mut exporter := new_in_memory_exporter()
	tracer := new_tracer('test-service', exporter)

	mut span := tracer.start_span('test-operation', SpanOptions{})
	assert span.name == 'test-operation'
	assert span.trace_id != ''
	assert span.span_id != ''
	assert span.start_time > 0

	span.set_attribute('k', 'v')
	tracer.finish(mut span)
	assert span.end_time >= span.start_time

	spans := exporter.get_spans()
	assert spans.len == 1
	assert spans[0].attributes['k'] == 'v'
}

fn test_span_hierarchy() {
	exporter := new_in_memory_exporter()
	tracer := new_tracer('test-service', exporter)

	mut parent := tracer.start_span('parent', SpanOptions{})
	mut child := tracer.start_span('child', SpanOptions{
		trace_id:  parent.trace_id
		parent_id: parent.span_id
	})
	assert child.trace_id == parent.trace_id
	assert child.parent_id == parent.span_id
	tracer.finish(mut child)
	tracer.finish(mut parent)
}

fn test_baggage() {
	mut ctx := Context{
		trace_id: generate_id()
		span_id:  generate_id()
		baggage:  {}
	}
	ctx.set_baggage('user-id', '12345')
	assert ctx.get_baggage('user-id') == '12345'
	assert ctx.get_baggage('missing') == ''
}

fn test_noop_exporter() {
	tracer := new_tracer('svc', new_noop_exporter())
	mut span := tracer.start_span('x', SpanOptions{})
	tracer.finish(mut span)
}

fn test_trace_string_operation() {
	mut exporter := new_in_memory_exporter()
	tracer := new_tracer('svc', exporter)
	out := trace_string_operation(tracer, 'op', fn () !string {
		return 'ok'
	}) or {
		assert false, '${err}'
		return
	}
	assert out == 'ok'
	assert exporter.get_spans().len == 1
}
