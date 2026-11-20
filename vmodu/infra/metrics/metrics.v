// metrics.v - Prometheus-compatible metrics collection
//
// Features:
//   - Counter, Gauge, Histogram metric types
//   - Label/dimension support
//   - Thread-safe operations
//   - Prometheus text format export
//
// Usage:
//   mut reg := metrics.new_registry('myapp')
//   mut counter := reg.new_counter('requests', 'Total requests', {})!
//   counter.inc()

module metrics

import sync
import time
import strings

// ============================================================================
// Enums
// ============================================================================

// MetricType identifies metric types
pub enum MetricType {
	counter
	gauge
	histogram
	summary
}

// String returns metric type name
pub fn (t MetricType) str() string {
	return match t {
		.counter   { 'counter' }
		.gauge     { 'gauge' }
		.histogram { 'histogram' }
		.summary   { 'summary' }
	}
}

// ============================================================================
// Types
// ============================================================================

// Labels for metric dimensions
pub type Labels = map[string]string

// Counter is a monotonically increasing counter
pub struct Counter {
pub mut:
	name   string
	help   string
	labels Labels
	value  u64
	mu     sync.Mutex
}

// Gauge can go up and down
pub struct Gauge {
pub mut:
	name   string
	help   string
	labels Labels
	value  f64
	mu     sync.Mutex
}

// Histogram buckets values
pub struct Histogram {
pub mut:
	name    string
	help    string
	labels  Labels
	buckets []f64
	counts  []u64
	sum     f64
	count   u64
	mu      sync.Mutex
}

// Registry holds all metrics
@[heap]
pub struct Registry {
pub mut:
	counters   map[string]&Counter
	gauges     map[string]&Gauge
	histograms map[string]&Histogram
	mu         sync.RwMutex
	prefix     string
}

// ============================================================================
// Constants
// ============================================================================

// default_buckets are standard histogram buckets (in seconds)
pub const default_buckets = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]

// ============================================================================
// Global Registry
// ============================================================================

// get_default creates/returns a shared registry without language globals.
// Prefer injecting `new_registry` in production code.
pub fn get_default() &Registry {
	return new_registry('vmodu')
}

// ============================================================================
// Registry Methods
// ============================================================================

// new_registry creates a new metrics registry
pub fn new_registry(prefix string) &Registry {
	return &Registry{
		counters:   map[string]&Counter{}
		gauges:     map[string]&Gauge{}
		histograms: map[string]&Histogram{}
		prefix:     prefix
	}
}

// make_key generates a unique key for a metric with labels
fn (r &Registry) make_key(name string, labels Labels) string {
	full_name := if r.prefix != '' { '${r.prefix}_${name}' } else { name }
	if labels.len == 0 {
		return full_name
	}
	return '${full_name}:${labels_key(labels)}'
}

// ============================================================================
// Counter Operations
// ============================================================================

// new_counter creates a counter
pub fn (mut r Registry) new_counter(name string, help string, labels Labels) !&Counter {
	key := r.make_key(name, labels)

	r.mu.lock()
	defer { r.mu.unlock() }

	if key in r.counters {
		return error('counter ${key} already exists')
	}

	c := &Counter{
		name:   if r.prefix != '' { '${r.prefix}_${name}' } else { name }
		help:   help
		labels: labels.clone()
		value:  0
	}
	r.counters[key] = c
	return c
}

// inc increments counter by 1
pub fn (mut c Counter) inc() {
	unsafe { c.mu.lock() }
	defer { unsafe { c.mu.unlock() } }
	c.value++
}

// add increments counter by n
pub fn (mut c Counter) add(n u64) {
	unsafe { c.mu.lock() }
	defer { unsafe { c.mu.unlock() } }
	c.value += n
}

// get returns current value
pub fn (c &Counter) get() u64 {
	unsafe { c.mu.lock() }
	defer { unsafe { c.mu.unlock() } }
	return c.value
}

// ============================================================================
// Gauge Operations
// ============================================================================

// new_gauge creates a gauge
pub fn (mut r Registry) new_gauge(name string, help string, labels Labels) !&Gauge {
	key := r.make_key(name, labels)

	r.mu.lock()
	defer { r.mu.unlock() }

	if key in r.gauges {
		return error('gauge ${key} already exists')
	}

	g := &Gauge{
		name:   if r.prefix != '' { '${r.prefix}_${name}' } else { name }
		help:   help
		labels: labels.clone()
		value:  0.0
	}
	r.gauges[key] = g
	return g
}

// set sets gauge value
pub fn (mut g Gauge) set(v f64) {
	unsafe { g.mu.lock() }
	defer { unsafe { g.mu.unlock() } }
	g.value = v
}

// inc increments gauge by 1
pub fn (mut g Gauge) inc() {
	unsafe { g.mu.lock() }
	defer { unsafe { g.mu.unlock() } }
	g.value++
}

// dec decrements gauge by 1
pub fn (mut g Gauge) dec() {
	unsafe { g.mu.lock() }
	defer { unsafe { g.mu.unlock() } }
	g.value--
}

// add adds to gauge
pub fn (mut g Gauge) add(v f64) {
	unsafe { g.mu.lock() }
	defer { unsafe { g.mu.unlock() } }
	g.value += v
}

// sub subtracts from gauge
pub fn (mut g Gauge) sub(v f64) {
	unsafe { g.mu.lock() }
	defer { unsafe { g.mu.unlock() } }
	g.value -= v
}

// get returns current value
pub fn (g &Gauge) get() f64 {
	unsafe { g.mu.lock() }
	defer { unsafe { g.mu.unlock() } }
	return g.value
}

// ============================================================================
// Histogram Operations
// ============================================================================

// new_histogram creates a histogram
pub fn (mut r Registry) new_histogram(name string, help string, labels Labels, buckets []f64) !&Histogram {
	key := r.make_key(name, labels)

	r.mu.lock()
	defer { r.mu.unlock() }

	if key in r.histograms {
		return error('histogram ${key} already exists')
	}

	use_buckets := if buckets.len > 0 { buckets } else { default_buckets }

	h := &Histogram{
		name:    if r.prefix != '' { '${r.prefix}_${name}' } else { name }
		help:    help
		labels:  labels.clone()
		buckets: use_buckets
		counts:  []u64{len: use_buckets.len + 1, init: 0}
		sum:     0.0
		count:   0
	}
	r.histograms[key] = h
	return h
}

// observe records a value
pub fn (mut h Histogram) observe(v f64) {
	unsafe { h.mu.lock() }
	defer { unsafe { h.mu.unlock() } }

	// Find bucket
	mut bucket_idx := h.buckets.len // +Inf bucket
	for i, bucket in h.buckets {
		if v <= bucket {
			bucket_idx = i
			break
		}
	}

	h.counts[bucket_idx]++
	h.sum += v
	h.count++
}

// get_count returns total observations
pub fn (h &Histogram) get_count() u64 {
	unsafe { h.mu.lock() }
	defer { unsafe { h.mu.unlock() } }
	return h.count
}

// get_sum returns sum of all observations
pub fn (h &Histogram) get_sum() f64 {
	unsafe { h.mu.lock() }
	defer { unsafe { h.mu.unlock() } }
	return h.sum
}

// ============================================================================
// Timer Utility
// ============================================================================

// Timer for measuring operation durations
pub struct Timer {
pub mut:
	histogram &Histogram
	start     i64
}

// start_timer begins timing
pub fn (h &Histogram) start_timer() Timer {
	return Timer{
		histogram: h
		start:     time.now().unix_milli()
	}
}

// observe_duration records elapsed time in seconds
pub fn (mut t Timer) observe_duration() {
	elapsed_ms := time.now().unix_milli() - t.start
	elapsed_sec := f64(elapsed_ms) / 1000.0
	t.histogram.observe(elapsed_sec)
}

// ============================================================================
// Prometheus Export
// ============================================================================

// PrometheusExporter exports metrics in Prometheus format
pub struct PrometheusExporter {
pub mut:
	registry &Registry
}

// new_exporter creates a Prometheus exporter
pub fn new_exporter(registry &Registry) &PrometheusExporter {
	return &PrometheusExporter{registry: registry}
}

// export returns metrics in Prometheus text format
pub fn (e &PrometheusExporter) export() string {
	mut sb := strings.new_builder(1000)
	e.export_counters(mut sb)
	e.export_gauges(mut sb)
	e.export_histograms(mut sb)
	return sb.str()
}

// export_counters exports all counters
fn (e &PrometheusExporter) export_counters(mut sb strings.Builder) {
	unsafe { e.registry.mu.rlock() }
	defer { unsafe { e.registry.mu.runlock() } }

	for _, counter in e.registry.counters {
		sb.writeln('# HELP ${counter.name} ${counter.help}')
		sb.writeln('# TYPE ${counter.name} counter')
		sb.write_string('${counter.name}')
		if counter.labels.len > 0 {
			sb.write_string('{')
			mut first := true
			for k, v in counter.labels {
				if !first { sb.write_string(',') }
				sb.write_string('${k}="${v}"')
				first = false
			}
			sb.write_string('}')
		}
		sb.writeln(' ${counter.get()}')
	}
}

// export_gauges exports all gauges
fn (e &PrometheusExporter) export_gauges(mut sb strings.Builder) {
	unsafe { e.registry.mu.rlock() }
	defer { unsafe { e.registry.mu.runlock() } }

	for _, gauge in e.registry.gauges {
		sb.writeln('# HELP ${gauge.name} ${gauge.help}')
		sb.writeln('# TYPE ${gauge.name} gauge')
		sb.write_string('${gauge.name}')
		if gauge.labels.len > 0 {
			sb.write_string('{')
			mut first := true
			for k, v in gauge.labels {
				if !first { sb.write_string(',') }
				sb.write_string('${k}="${v}"')
				first = false
			}
			sb.write_string('}')
		}
		sb.writeln(' ${gauge.get()}')
	}
}

// export_histograms exports all histograms
fn (e &PrometheusExporter) export_histograms(mut sb strings.Builder) {
	unsafe { e.registry.mu.rlock() }
	defer { unsafe { e.registry.mu.runlock() } }

	for _, hist in e.registry.histograms {
		sb.writeln('# HELP ${hist.name} ${hist.help}')
		sb.writeln('# TYPE ${hist.name} histogram')

		// Export buckets
		mut cumulative := u64(0)
		for i, bucket in hist.buckets {
			cumulative += hist.counts[i]
			sb.write_string('${hist.name}_bucket{le="${bucket}"}')
			if hist.labels.len > 0 {
				sb.write_string(',')
				mut first := true
				for k, v in hist.labels {
					if !first { sb.write_string(',') }
					sb.write_string('${k}="${v}"')
					first = false
				}
			}
			sb.writeln(' ${cumulative}')
		}
		// +Inf bucket
		cumulative += hist.counts[hist.buckets.len]
		sb.writeln('${hist.name}_bucket{le="+Inf"} ${cumulative}')

		sb.writeln('${hist.name}_sum ${hist.sum}')
		sb.writeln('${hist.name}_count ${hist.count}')
	}
}

// ============================================================================
// Helpers
// ============================================================================

// labels_key generates a sorted key from labels
fn labels_key(labels Labels) string {
	if labels.len == 0 {
		return ''
	}
	mut parts := []string{cap: labels.len}
	for k, v in labels {
		parts << '${k}=${v}'
	}
	parts.sort()
	return parts.join(',')
}

// ============================================================================
// Global Convenience Functions
// ============================================================================

// counter creates a counter in the default registry
pub fn counter(name string, help string) !&Counter {
	mut reg := get_default()
	return reg.new_counter(name, help, map[string]string{})
}

// gauge creates a gauge in the default registry
pub fn gauge(name string, help string) !&Gauge {
	mut reg := get_default()
	return reg.new_gauge(name, help, map[string]string{})
}

// histogram creates a histogram in the default registry
pub fn histogram(name string, help string) !&Histogram {
	mut reg := get_default()
	return reg.new_histogram(name, help, map[string]string{}, default_buckets)
}
