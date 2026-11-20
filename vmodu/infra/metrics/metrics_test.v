// metrics_test.v - Unit tests for Prometheus-compatible metrics

module metrics

// test_new_registry tests creating a new metrics registry
fn test_new_registry() {
	reg := new_registry('testapp')
	
	assert reg.prefix == 'testapp'
	assert reg.counters.len == 0
	assert reg.gauges.len == 0
	assert reg.histograms.len == 0
}

// test_new_counter tests creating a counter
fn test_new_counter() {
	mut reg := new_registry('test')
	
	c := reg.new_counter('requests', 'Total requests', map[string]string{}) or {
		return
	}
	
	assert c.name == 'test_requests'
	assert c.help == 'Total requests'
	assert c.value == 0
}

// test_counter_inc tests incrementing counter
fn test_counter_inc() {
	mut reg := new_registry('test')
	
	mut c := reg.new_counter('counter', 'Test counter', map[string]string{}) or { return }
	
	assert c.get() == 0
	
	c.inc()
	assert c.get() == 1
	
	c.inc()
	c.inc()
	assert c.get() == 3
}

// test_counter_add tests adding to counter
fn test_counter_add() {
	mut reg := new_registry('test')
	
	mut c := reg.new_counter('counter', 'Test', map[string]string{}) or { return }
	
	c.add(5)
	assert c.get() == 5
	
	c.add(10)
	assert c.get() == 15
}

// test_new_gauge tests creating a gauge
fn test_new_gauge() {
	mut reg := new_registry('test')
	
	g := reg.new_gauge('connections', 'Active connections', map[string]string{}) or {
		return
	}
	
	assert g.name == 'test_connections'
	assert g.help == 'Active connections'
	assert g.value == 0.0
}

// test_gauge_set tests setting gauge value
fn test_gauge_set() {
	mut reg := new_registry('test')
	
	mut g := reg.new_gauge('gauge', 'Test', map[string]string{}) or { return }
	
	g.set(42.0)
	assert g.get() == 42.0
	
	g.set(100.5)
	assert g.get() == 100.5
}

// test_gauge_inc_dec tests increment and decrement
fn test_gauge_inc_dec() {
	mut reg := new_registry('test')
	
	mut g := reg.new_gauge('gauge', 'Test', map[string]string{}) or { return }
	
	g.set(10.0)
	
	g.inc()
	assert g.get() == 11.0
	
	g.dec()
	assert g.get() == 10.0
}

// test_gauge_add_sub tests adding and subtracting
fn test_gauge_add_sub() {
	mut reg := new_registry('test')
	
	mut g := reg.new_gauge('gauge', 'Test', map[string]string{}) or { return }
	
	g.set(10.0)
	
	g.add(5.0)
	assert g.get() == 15.0
	
	g.sub(3.0)
	assert g.get() == 12.0
}

// test_gauge_negative_values tests gauge can be negative
fn test_gauge_negative_values() {
	mut reg := new_registry('test')
	
	mut g := reg.new_gauge('gauge', 'Test', map[string]string{}) or { return }
	
	g.set(-10.0)
	assert g.get() == -10.0
	
	g.sub(5.0)
	assert g.get() == -15.0
}

// test_new_histogram tests creating histogram
fn test_new_histogram() {
	mut reg := new_registry('test')
	
	h := reg.new_histogram('duration', 'Request duration', map[string]string{}, [0.1, 0.5, 1.0]) or {
		return
	}
	
	assert h.name == 'test_duration'
	assert h.help == 'Request duration'
	assert h.buckets.len == 3
	assert h.buckets[0] == 0.1
	assert h.buckets[1] == 0.5
	assert h.buckets[2] == 1.0
	assert h.counts.len == 4  // 3 buckets + 1 for +Inf
	assert h.count == 0
}

// test_histogram_default_buckets tests default buckets
fn test_histogram_default_buckets() {
	mut reg := new_registry('test')
	
	h := reg.new_histogram('duration', 'Test', map[string]string{}, []) or { return }
	
	assert h.buckets.len == default_buckets.len
	assert h.buckets[0] == 0.005
	assert h.buckets[default_buckets.len - 1] == 10.0
}

// test_histogram_observe tests observing values
fn test_histogram_observe() {
	mut reg := new_registry('test')
	
	mut h := reg.new_histogram('duration', 'Test', map[string]string{}, [0.1, 0.5, 1.0]) or { return }
	
	h.observe(0.05)  // Goes to bucket 0
	h.observe(0.3)   // Goes to bucket 1
	h.observe(0.8)   // Goes to bucket 2
	h.observe(2.0)   // Goes to +Inf bucket
	
	assert h.get_count() == 4
}

// test_counter_with_labels tests counter with labels
fn test_counter_with_labels() {
	mut reg := new_registry('test')
	
	labels := {
		'method': 'GET'
		'status': '200'
	}
	
	c := reg.new_counter('requests', 'Total requests', labels) or { return }
	
	assert c.labels['method'] == 'GET'
	assert c.labels['status'] == '200'
}

// test_duplicate_counter_registration tests duplicate registration fails
fn test_duplicate_counter_registration() {
	mut reg := new_registry('test')
	
	reg.new_counter('same', 'First', map[string]string{}) or { return }
	
	reg.new_counter('same', 'Second', map[string]string{}) or {
		assert err.msg().contains('already exists')
		return
	}
	
	assert false, 'should fail for duplicate registration'
}

// test_metric_type_enum tests metric type strings
fn test_metric_type_enum() {
	assert MetricType.counter.str() == 'counter'
	assert MetricType.gauge.str() == 'gauge'
	assert MetricType.histogram.str() == 'histogram'
	assert MetricType.summary.str() == 'summary'
}

// test_get_default_registry tests global registry
fn test_get_default_registry() {
	reg := get_default()
	
	assert reg != unsafe { nil }
	assert reg.prefix == 'vmodu'
}

// test_registry_prefix tests registry prefixing
fn test_registry_prefix() {
	mut reg1 := new_registry('app1')
	mut reg2 := new_registry('app2')
	
	c1 := reg1.new_counter('metric', 'Test', map[string]string{}) or { return }
	c2 := reg2.new_counter('metric', 'Test', map[string]string{}) or { return }
	
	assert c1.name == 'app1_metric'
	assert c2.name == 'app2_metric'
}

// test_labels_key tests labels key generation
fn test_labels_key() {
	labels1 := {
		'a': '1'
		'b': '2'
	}
	
	labels2 := {
		'b': '2'
		'a': '1'
	}
	
	// Same labels in different order should produce same key
	key1 := labels_key(labels1)
	key2 := labels_key(labels2)
	
	assert key1 == key2
	
	// Different labels should produce different keys
	labels3 := {
		'a': '1'
		'b': '3'
	}
	
	key3 := labels_key(labels3)
	assert key1 != key3
}

// test_empty_labels tests empty labels handling
fn test_empty_labels() {
	mut reg := new_registry('test')
	
	c := reg.new_counter('metric', 'Test', map[string]string{}) or { return }
	
	assert c.labels.len == 0
}

// test_counter_thread_safety tests concurrent increments
fn test_counter_thread_safety() {
	mut reg := new_registry('test')
	mut c := reg.new_counter('concurrent', 'Test', map[string]string{}) or { return }
	
	// Multiple increments
	for _ in 0..100 {
		c.inc()
	}
	
	assert c.get() == 100
}

// test_gauge_thread_safety tests concurrent gauge operations
fn test_gauge_thread_safety() {
	mut reg := new_registry('test')
	mut g := reg.new_gauge('gauge', 'Test', map[string]string{}) or { return }
	
	g.set(0.0)
	
	// Multiple operations
	for _ in 0..50 {
		g.inc()
	}
	
	for _ in 0..50 {
		g.dec()
	}
	
	// Should be back to 0
	assert g.get() == 0.0
}
