// bench.v - Benchmark and performance testing for VModulith Runtime
// v3.3: Performance measurement and optimization utilities

module bench

import time
import strings

// BenchmarkResult contains benchmark results
pub struct BenchmarkResult {
pub:
	name           string
	iterations     int
	duration_ns    i64
	ns_per_op      f64
	ops_per_sec    f64
}

// Benchmarker runs benchmarks
pub struct Benchmarker {
pub mut:
	results []BenchmarkResult
}

// new_benchmarker creates a new benchmarker
pub fn new_benchmarker() Benchmarker {
	return Benchmarker{results: []}
}

// benchmark runs a benchmark function
pub fn (mut b Benchmarker) benchmark(name string, iterations int, bench_fn fn ()) BenchmarkResult {
	// Warmup
	for _ in 0..10 { bench_fn() }
	
	start := time.now()
	for _ in 0..iterations { bench_fn() }
	elapsed := time.now() - start
	
	result := BenchmarkResult{
		name:        name
		iterations:  iterations
		duration_ns: elapsed.nanoseconds()
		ns_per_op:   f64(elapsed.nanoseconds()) / f64(iterations)
		ops_per_sec: f64(iterations) / (f64(elapsed.nanoseconds()) / 1_000_000_000.0)
	}
	b.results << result
	return result
}

// print_results prints all benchmark results
pub fn (b &Benchmarker) print_results() {
	println('')
	println('Benchmark Results')
	println(strings.repeat(`=`, 70))
	println('Name                    Iterations  Duration    ns/op       ops/sec')
	println(strings.repeat(`-`, 70))
	for result in b.results {
		name_padded := result.name + strings.repeat(` `, 24 - result.name.len)
		println('${name_padded} ${result.iterations:10} ${format_duration(result.duration_ns):10} ${result.ns_per_op:10.2f} ${result.ops_per_sec:10.2f}')
	}
	println(strings.repeat(`=`, 70))
}

fn format_duration(ns i64) string {
	if ns < 1000 { return '${ns}ns' }
	else if ns < 1_000_000 { return '${ns / 1000}us' }
	else if ns < 1_000_000_000 { return '${ns / 1_000_000}ms' }
	else { return '${ns / 1_000_000_000}s' }
}

// Profile tracks performance metrics
pub struct Profile {
pub mut:
	name       string
	call_count u64
	total_time i64
}

pub fn new_profile(name string) Profile {
	return Profile{name: name}
}

pub fn (mut p Profile) record(elapsed i64) {
	p.total_time += elapsed
	p.call_count++
}

pub fn (p &Profile) get_avg() i64 {
	if p.call_count == 0 { return 0 }
	return p.total_time / i64(p.call_count)
}

// LoadTestResult contains load test results
pub struct LoadTestResult {
pub:
	total_requests u64
	success_count  u64
	error_count    u64
	avg_latency_ns i64
	rps            f64
}

// print prints load test results
pub fn (r &LoadTestResult) print() {
	println('Load Test Results')
	println('Total: ${r.total_requests}, Success: ${r.success_count}, Errors: ${r.error_count}')
	println('RPS: ${r.rps:.2f}, Avg Latency: ${format_duration(r.avg_latency_ns)}')
}
