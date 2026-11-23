// tracing.v — optional OpenTelemetry-ish HTTP server span hooks
module http

import vmodu.infra.trace

// trace_middleware starts a server span per request and finishes it after the handler.
// Sets response headers X-Trace-Id and X-Span-Id. Pass a tracer with NoopExporter to disable export.
pub fn trace_middleware(tracer &trace.Tracer) Middleware {
	return fn [tracer] (next HandlerFunc) HandlerFunc {
		return fn [tracer, next] (ctx Context) !Response {
			mut attrs := {
				'http.method':     ctx.method
				'http.path':       ctx.path
				'http.request_id': ctx.request_id
				'net.peer.ip':     ctx.client_ip
			}
			mut span := tracer.start_span('HTTP ${ctx.method} ${ctx.path}', trace.SpanOptions{
				kind:       .server
				attributes: attrs
			})
			mut resp := next(ctx) or {
				span.set_error()
				span.set_attribute('error', err.msg())
				tracer.finish(mut span)
				return err
			}
			if resp.status_code >= 500 {
				span.set_error()
			} else {
				span.set_ok()
			}
			span.set_attribute('http.status_code', resp.status_code.str())
			resp.headers['X-Trace-Id'] = span.trace_id
			resp.headers['X-Span-Id'] = span.span_id
			tracer.finish(mut span)
			return resp
		}
	}
}
