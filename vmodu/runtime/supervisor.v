// supervisor.v - Actor Supervision Tree for VModulith Runtime
// v3.2: Production-ready supervision with multiple restart strategies

module runtime

import time
import sync

// RestartStrategy defines how to restart failed actors
pub enum RestartStrategy {
	one_for_one    // Restart only the failed child
	one_for_all    // Restart all children
	rest_for_one   // Restart failed child and all children started after it
}

// ChildSpec defines a child actor specification
pub struct ChildSpec {
pub:
	id            string
	start_fn      ?fn () !&Actor  // Function to start the actor
	restart       RestartType
	max_restarts  int = 5
	restart_window int = 60  // seconds
}

// RestartType defines when to restart a child
pub enum RestartType {
	permanent  // Always restart
	temporary  // Never restart
	transient  // Restart only if abnormal exit
}

// Child represents a supervised child actor
pub struct Child {
pub:
	spec       ChildSpec
pub mut:
	actor      ?&Actor
	restarts   []i64  // timestamps of recent restarts
	start_time i64
	status     ChildStatus
}

// ChildStatus represents the status of a child
pub enum ChildStatus {
	starting
	running
	restarting
	stopped
	failed
}

// Supervisor manages a group of child actors
pub struct Supervisor {
pub:
	id        string
	strategy  RestartStrategy
	max_restarts int = 10
	restart_window int = 60  // seconds
pub mut:
	children  map[string]Child
	is_running bool
	mu        sync.RwMutex
}

// new_supervisor creates a new supervisor
pub fn new_supervisor(id string, strategy RestartStrategy) &Supervisor {
	return &Supervisor{
		id:             id
		strategy:       strategy
		children:       {}
		is_running:     false
		max_restarts:   10
		restart_window: 60
	}
}

// add_child adds a child specification
pub fn (mut s Supervisor) add_child(spec ChildSpec) {
	s.mu.lock()
	defer { s.mu.unlock() }
	
	s.children[spec.id] = Child{
		spec:       spec
		actor:      none
		restarts:   []
		start_time: 0
		status:     .stopped
	}
}

// start starts the supervisor and all children
pub fn (mut s Supervisor) start() ! {
	if s.is_running {
		return error('supervisor already running')
	}
	
	s.mu.lock()
	defer { s.mu.unlock() }
	
	s.is_running = true
	
	// Start all children
	for id, child in s.children {
		if child.spec.restart == .permanent {
			s.start_child(id) or {
				s.is_running = false
				return error('failed to start child ${id}: ${err}')
			}
		}
	}
	
	println('[Supervisor] ${s.id} started with ${s.children.len} children')
	
	// Start monitoring loop
	spawn s.monitor_loop()
}

// stop stops the supervisor and all children
pub fn (mut s Supervisor) stop() {
	s.mu.lock()
	defer { s.mu.unlock() }
	
	s.is_running = false
	
	// Stop all children in reverse order
	for id, _ in s.children {
		s.stop_child(id)
	}
	
	println('[Supervisor] ${s.id} stopped')
}

// start_child starts a specific child
fn (mut s Supervisor) start_child(id string) ! {
	if mut child := s.children[id] {
		child.status = .starting
		child.start_time = time.now().unix_milli()
		
		// Create and start the actor
		actor := if f := child.spec.start_fn {
			f() or {
				child.status = .failed
				s.children[id] = child
				return err
			}
		} else {
			return error('start_fn not set')
		}
		
		child.actor = actor
		child.status = .running
		s.children[id] = child
		
		println('[Supervisor] Child ${id} started')
	}
}

// stop_child stops a specific child
fn (mut s Supervisor) stop_child(id string) {
	if mut child := s.children[id] {
		if mut actor := child.actor {
			actor.stop()
		}
		child.actor = none
		child.status = .stopped
		s.children[id] = child
	}
}

// restart_child restarts a failed child
fn (mut s Supervisor) restart_child(id string) ! {
	if mut child := s.children[id] {
		// Check restart limits
		now := time.now().unix_milli()
		window_start := now - i64(child.spec.restart_window * 1000)
		
		// Filter restarts within window
		mut recent_restarts := []i64{}
		for restart_time in child.restarts {
			if restart_time > window_start {
				recent_restarts << restart_time
			}
		}
		
		if recent_restarts.len >= child.spec.max_restarts {
			return error('max restarts exceeded for ${id}')
		}
		
		// Record restart
		recent_restarts << now
		child.restarts = recent_restarts
		
		// Stop current instance
		s.stop_child(id)
		
		// Restart based on strategy
		match s.strategy {
			.one_for_one {
				child.status = .restarting
				s.children[id] = child
				s.start_child(id)!
			}
			.one_for_all {
				// Restart all children
				s.restart_all_children()
			}
			.rest_for_one {
				// Restart this child and all children started after it
				s.restart_rest_for_one(id)
			}
		}
	}
}

// restart_all_children restarts all children
fn (mut s Supervisor) restart_all_children() {
	// Stop all
	for id, _ in s.children {
		s.stop_child(id)
	}
	
	// Restart permanent ones
	for id, child in s.children {
		if child.spec.restart == .permanent {
			s.start_child(id) or {
				eprintln('Failed to restart child ${id}: ${err}')
			}
		}
	}
}

// restart_rest_for_one restarts child and all started after it
fn (mut s Supervisor) restart_rest_for_one(start_id string) {
	mut found := false
	
	for id, _ in s.children {
		if id == start_id {
			found = true
		}
		
		if found {
			s.stop_child(id)
			s.start_child(id) or {
				eprintln('Failed to restart child ${id}: ${err}')
			}
		}
	}
}

// monitor_loop monitors children health
fn (mut s Supervisor) monitor_loop() {
	for s.is_running {
		s.check_children_health()
		time.sleep(1 * time.second)
	}
}

// check_children_health checks if all children are healthy
fn (mut s Supervisor) check_children_health() {
	s.mu.lock()
	defer { s.mu.unlock() }
	
	for id, child in s.children {
		if child.status == .running {
			if actor := child.actor {
				if !actor.is_running() {
					// Actor has stopped unexpectedly
					match child.spec.restart {
						.permanent {
							s.restart_child(id) or {
								eprintln('Failed to restart child ${id}: ${err}')
							}
						}
						.transient {
							// Only restart if not normal exit (we can't detect this easily)
							// For now, restart anyway
							s.restart_child(id) or {
								eprintln('Failed to restart child ${id}: ${err}')
							}
						}
						.temporary {
							// Mark as stopped, don't restart
							if mut c := s.children[id] {
								c.status = .stopped
								s.children[id] = c
							}
						}
					}
				}
			}
		}
	}
}

// get_child returns a child actor
pub fn (mut s Supervisor) get_child(id string) ?&Actor {
	s.mu.rlock()
	defer { unsafe { s.mu.runlock() } }
	
	if child := s.children[id] {
		return child.actor
	}
	return none
}

// get_stats returns supervisor statistics
pub fn (mut s Supervisor) get_stats() SupervisorStats {
	s.mu.rlock()
	defer { unsafe { s.mu.runlock() } }
	
	mut running := 0
	mut failed := 0
	
	for _, child in s.children {
		match child.status {
			.running { running++ }
			.failed  { failed++ }
			else {}
		}
	}
	
	return SupervisorStats{
		id:             s.id
		strategy:       s.strategy.str()
		children_total: s.children.len
		children_running: running
		children_failed:  failed
		is_running:     s.is_running
	}
}

// SupervisorStats contains supervisor metrics
pub struct SupervisorStats {
pub:
	id               string
	strategy         string
	children_total   int
	children_running int
	children_failed  int
	is_running       bool
}

// str returns string representation of RestartStrategy
pub fn (r RestartStrategy) str() string {
	return match r {
		.one_for_one  { 'one_for_one' }
		.one_for_all  { 'one_for_all' }
		.rest_for_one { 'rest_for_one' }
	}
}

// Helper to create a simple supervised actor
pub fn supervise_actor(id string, actor_fn fn () !&Actor) !&Supervisor {
	mut sup := new_supervisor('sup_${id}', .one_for_one)
	sup.add_child(ChildSpec{
		id:            id
		start_fn:      actor_fn
		restart:       .permanent
		max_restarts:  5
		restart_window: 60
	})
	sup.start()!
	return sup
}
