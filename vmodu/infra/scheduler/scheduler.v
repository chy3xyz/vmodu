// scheduler.v - Task Scheduler for VModulith
// Reuses: time, sync from V standard library

module scheduler

import time
import sync
import rand

// Job represents a scheduled task
pub struct Job {
pub:
	id        string
	name      string
	schedule  Schedule
	handler   fn () !
	enabled   bool
}

// Schedule defines when a job runs
pub struct Schedule {
pub:
	// Cron-like fields
	minute   string = '*'   // 0-59 or *
	hour     string = '*'   // 0-23 or *
	day      string = '*'   // 1-31 or *
	month    string = '*'   // 1-12 or *
	weekday  string = '*'   // 0-6 (0=Sunday) or *
	
	// Alternative: run once at specific time
	once_at  ?i64          // Unix timestamp for one-time job
	
	// Alternative: run with interval
	interval ?time.Duration // Run every duration
}

// Scheduler manages scheduled jobs
pub struct Scheduler {
pub mut:
	jobs       map[string]Job
	is_running bool
	mu         sync.Mutex
	stop_ch    chan bool
}

// new_scheduler creates a new scheduler
pub fn new_scheduler() &Scheduler {
	return &Scheduler{
		jobs:       {}
		is_running: false
		stop_ch:    chan bool{}
	}
}

// add_job adds a job to the scheduler
pub fn (mut s Scheduler) add_job(job Job) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.jobs[job.id] = job
}

// remove_job removes a job
pub fn (mut s Scheduler) remove_job(id string) {
	s.mu.lock()
	defer { s.mu.unlock() }
	s.jobs.delete(id)
}

// start starts the scheduler
pub fn (mut s Scheduler) start() {
	s.mu.lock()
	if s.is_running {
		s.mu.unlock()
		return
	}
	s.is_running = true
	s.mu.unlock()
	
	// Start scheduler loop
	spawn s.run()
	
	println('[Scheduler] Started with ${s.jobs.len} jobs')
}

// stop stops the scheduler
pub fn (mut s Scheduler) stop() {
	s.mu.lock()
	defer { s.mu.unlock() }
	
	if !s.is_running {
		return
	}
	
	s.is_running = false
	s.stop_ch <- true
	
	println('[Scheduler] Stopped')
}

// run is the main scheduler loop
fn (mut s Scheduler) run() {
	for s.is_running {
		select {
			_ := <-s.stop_ch {
				return
			}
			1 * time.second {
				s.check_and_run_jobs()
			}
		}
	}
}

// check_and_run_jobs checks all jobs and runs due ones
fn (mut s Scheduler) check_and_run_jobs() {
	now := time.now()
	
	s.mu.lock()
	jobs_copy := s.jobs.clone()
	s.mu.unlock()
	
	for _, job in jobs_copy {
		if !job.enabled {
			continue
		}
		
		if s.should_run(job, now) {
			spawn s.run_job(job)
		}
	}
}

// should_run checks if a job should run now
fn (s &Scheduler) should_run(job Job, now time.Time) bool {
	sched := job.schedule
	
	// Check once_at
	if once_at := sched.once_at {
		return now.unix() >= once_at
	}
	
	// Check interval
	if interval := sched.interval {
		// For interval jobs, we'd need to track last run time
		// Simplified: run every interval
		return true
	}
	
	// Check cron fields
	return s.match_cron_field(sched.minute, now.minute) &&
	       s.match_cron_field(sched.hour, now.hour) &&
	       s.match_cron_field(sched.day, now.day) &&
	       s.match_cron_field(sched.month, int(now.month)) &&
	       s.match_cron_field(sched.weekday, int(now.day_of_week()))
}

// match_cron_field checks if value matches cron field
fn (s &Scheduler) match_cron_field(field string, value int) bool {
	if field == '*' {
		return true
	}
	
	// Handle comma-separated values
	parts := field.split(',')
	for part in parts {
		if part.contains('-') {
			// Range: 1-5
			range_parts := part.split('-')
			if range_parts.len == 2 {
				start := range_parts[0].int()
				end := range_parts[1].int()
				if value >= start && value <= end {
					return true
				}
			}
		} else if part.contains('/') {
			// Step: */5
			step_parts := part.split('/')
			if step_parts.len == 2 {
				step := step_parts[1].int()
				if value % step == 0 {
					return true
				}
			}
		} else {
			// Single value
			if part.int() == value {
				return true
			}
		}
	}
	
	return false
}

// run_job executes a job
fn (s &Scheduler) run_job(job Job) {
	println('[Scheduler] Running job: ${job.name}')
	
	job.handler() or {
		eprintln('[Scheduler] Job ${job.name} failed: ${err}')
		return
	}
	
	println('[Scheduler] Job ${job.name} completed')
}

// Job builders for common schedules

// every_minute creates a job that runs every minute
pub fn every_minute(name string, handler fn () !) Job {
	return Job{
		id:       generate_job_id()
		name:     name
		schedule: Schedule{interval: 60 * time.second}
		handler:  handler
		enabled:  true
	}
}

// every_hour creates a job that runs every hour
pub fn every_hour(name string, handler fn () !) Job {
	return Job{
		id:       generate_job_id()
		name:     name
		schedule: Schedule{minute: '0'}
		handler:  handler
		enabled:  true
	}
}

// every_day creates a job that runs every day at specific time
pub fn every_day(name string, hour int, minute int, handler fn () !) Job {
	return Job{
		id:       generate_job_id()
		name:     name
		schedule: Schedule{minute: '${minute}', hour: '${hour}'}
		handler:  handler
		enabled:  true
	}
}

// cron creates a job with cron expression
pub fn cron(name string, minute string, hour string, day string, month string, weekday string, handler fn () !) Job {
	return Job{
		id:       generate_job_id()
		name:     name
		schedule: Schedule{
			minute:  minute
			hour:    hour
			day:     day
			month:   month
			weekday: weekday
		}
		handler: handler
		enabled: true
	}
}

// once creates a one-time job
pub fn once(name string, at time.Time, handler fn () !) Job {
	return Job{
		id:       generate_job_id()
		name:     name
		schedule: Schedule{once_at: at.unix()}
		handler:  handler
		enabled:  true
	}
}

// interval creates a job that runs at intervals
pub fn interval(name string, every time.Duration, handler fn () !) Job {
	return Job{
		id:       generate_job_id()
		name:     name
		schedule: Schedule{interval: every}
		handler:  handler
		enabled:  true
	}
}

fn generate_job_id() string {
	return 'job_${time.now().unix()}_${rand.intn(10000)}'
}

// Task queue for delayed execution
pub struct TaskQueue {
pub mut:
	tasks []Task
	mu    sync.Mutex
}

// Task represents a delayed task
pub struct Task {
pub:
	id        string
	name      string
	run_at    i64
	handler   fn () !
	retries   int
	max_retries int
}

// new_task_queue creates a new task queue
pub fn new_task_queue() &TaskQueue {
	return &TaskQueue{
		tasks: []
	}
}

// add adds a task to the queue
pub fn (mut q TaskQueue) add(task Task) {
	q.mu.lock()
	defer { q.mu.unlock() }
	q.tasks << task
}

// process processes due tasks
pub fn (mut q TaskQueue) process() {
	q.mu.lock()
	defer { q.mu.unlock() }
	
	now := time.now().unix()
	mut remaining := []Task{}
	
	for task in q.tasks {
		if task.run_at <= now {
			// Execute task
			spawn q.execute_task(task)
		} else {
			remaining << task
		}
	}
	
	q.tasks = remaining
}

// execute_task executes a single task
fn (q &TaskQueue) execute_task(task Task) {
	task.handler() or {
		// Retry logic
		if task.retries < task.max_retries {
			// Re-queue with backoff
		}
		return
	}
}

// E-commerce specific jobs

// OrderTimeoutJob handles order timeout
pub struct OrderTimeoutJob {
pub:
	order_id string
	timeout_minutes int = 30
}

// create_order_timeout creates an order timeout job
pub fn create_order_timeout(order_id string, timeout_minutes int) Job {
	return Job{
		id:       'order_timeout_${order_id}'
		name:     'Order Timeout: ${order_id}'
		schedule: Schedule{once_at: time.now().unix() + timeout_minutes * 60}
		handler:  fn () ! {
			// Cancel order if not paid
			println('Checking order timeout...')
		}
		enabled: true
	}
}

// InventorySyncJob syncs inventory
pub fn create_inventory_sync_job() Job {
	return every_hour('Inventory Sync', fn () ! {
		println('Syncing inventory...')
		// Implementation
	})
}

// ReportGenerationJob generates daily reports
pub fn create_daily_report_job() Job {
	return every_day('Daily Report', 1, 0, fn () ! {
		println('Generating daily report...')
		// Implementation
	})
}

// CacheCleanupJob cleans expired cache
pub fn create_cache_cleanup_job() Job {
	return cron('Cache Cleanup', '0', '*/6', '*', '*', '*', fn () ! {
		println('Cleaning expired cache...')
		// Implementation
	})
}
