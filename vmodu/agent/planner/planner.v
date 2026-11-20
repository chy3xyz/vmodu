// planner.v - AI Task Planner for VModulith Runtime
// v3.1: Production-ready task decomposition with LLM integration

module planner

import vmodu.agent.llm
import json2
import time

// Task represents a task to be planned
pub struct Task {
pub:
	id          string
	description string
	priority    Priority
	deadline    ?i64 // Unix timestamp
	constraints []string
}

// Priority levels
pub enum Priority {
	low
	medium
	high
	critical
}

// Step is a single step in a plan
pub struct Step {
pub:
	id                 string
	action             string
	description        string
	depends_on         []string
	status             StepStatus
	estimated_duration int // minutes
}

// StepStatus represents step execution status
pub enum StepStatus {
	pending
	in_progress
	completed
	failed
	skipped
}

// Plan is the result of task decomposition
pub struct Plan {
pub:
	task_id                  string
	goal                     string
	steps                    []Step
	confidence               f64
	created_at               i64
	estimated_total_duration int // minutes
}

// Planner creates and manages plans
pub struct Planner {
pub mut:
	llm_client &llm.Client
	plans      map[string]Plan
	max_steps  int = 10
}

// new_planner creates a new planner
pub fn new_planner(client &llm.Client) Planner {
	return Planner{
		llm_client: client
		plans:      {}
		max_steps:  10
	}
}

// PlanResult is the structured result from LLM
struct PlanResult {
pub:
	goal       string     @[json: 'goal']
	steps      []StepData @[json: 'steps']
	confidence f64        @[json: 'confidence']
}

// StepData for JSON parsing
struct StepData {
pub:
	action             string   @[json: 'action']
	description        string   @[json: 'description']
	depends_on         []string @[json: 'depends_on']
	estimated_duration int      @[json: 'estimated_duration_minutes']
}

// decompose breaks down a task into actionable steps
pub fn (mut p Planner) decompose(task Task) !Plan {
	// Build prompt for LLM
	prompt := p.build_decomposition_prompt(task)

	// Call LLM
	messages := [
		llm.Message{ role: 'system', content: p.get_system_prompt() }
		llm.Message{ role: 'user', content: prompt },
	]

	resp := p.llm_client.complete(messages)!

	// Parse the JSON response
	plan_result := p.parse_plan_response(resp.content) or {
		// Fallback to simple plan if parsing fails
		return p.create_fallback_plan(task)
	}

	// Build plan with IDs
	mut steps := []Step{}
	mut total_duration := 0

	for i, step_data in plan_result.steps {
		step := Step{
			id:                 'step_${i + 1}'
			action:             step_data.action
			description:        step_data.description
			depends_on:         step_data.depends_on
			status:             .pending
			estimated_duration: step_data.estimated_duration
		}
		steps << step
		total_duration += step_data.estimated_duration
	}

	plan := Plan{
		task_id:                  task.id
		goal:                     task.description
		steps:                    steps
		confidence:               plan_result.confidence
		created_at:               time.now().unix_milli()
		estimated_total_duration: total_duration
	}

	// Store plan
	p.plans[task.id] = plan

	return plan
}

// build_decomposition_prompt builds the prompt for task decomposition
fn (p Planner) build_decomposition_prompt(task Task) string {
	mut prompt := 'Decompose the following task into specific, actionable steps.\n\n'
	prompt += 'Task: "${task.description}"\n\n'

	if task.constraints.len > 0 {
		prompt += 'Constraints:\n'
		for constraint in task.constraints {
			prompt += '- ${constraint}\n'
		}
		prompt += '\n'
	}

	prompt += 'Priority: ${task.priority.str()}\n\n'
	prompt += 'Provide your response in the following JSON format:\n'
	prompt += '```json\n'
	prompt += '{\n'
	prompt += '  "goal": "brief summary of the goal",\n'
	prompt += '  "confidence": 0.85,\n'
	prompt += '  "steps": [\n'
	prompt += '    {\n'
	prompt += '      "action": "step_name",\n'
	prompt += '      "description": "detailed description",\n'
	prompt += '      "depends_on": [],\n'
	prompt += '      "estimated_duration_minutes": 30\n'
	prompt += '    }\n'
	prompt += '  ]\n'
	prompt += '}\n'
	prompt += '```\n\n'
	prompt += 'Guidelines:\n'
	prompt += '- Create 3-7 steps\n'
	prompt += '- Each step should be concrete and actionable\n'
	prompt += '- Use depends_on to specify dependencies (use step indices 0-based)\n'
	prompt += '- Estimate realistic durations\n'
	prompt += '- Consider the priority and constraints\n'

	return prompt
}

// get_system_prompt returns the system prompt for the planner
fn (p Planner) get_system_prompt() string {
	return 'You are an expert task planner. Your job is to break down complex tasks into specific, ' +
		'actionable steps. You provide clear, structured plans with realistic time estimates. ' +
		'Always respond in valid JSON format.'
}

// parse_plan_response parses the LLM response
fn (p Planner) parse_plan_response(content string) !PlanResult {
	// Extract JSON from markdown code blocks if present
	mut json_str := content

	// Try to find JSON in code blocks
	if start := content.index('```json') {
		if end := content.index_after('```', start + 7) {
			json_str = content[start + 7..end].trim_space()
		}
	} else if start := content.index('```') {
		if end := content.index_after('```', start + 3) {
			json_str = content[start + 3..end].trim_space()
		}
	}

	// Parse JSON
	result := json2.decode[PlanResult](json_str) or {
		return error('Failed to parse plan JSON: ${err}')
	}

	// Validate
	if result.steps.len == 0 {
		return error('No steps in plan')
	}

	return result
}

// create_fallback_plan creates a simple fallback plan
fn (p Planner) create_fallback_plan(task Task) Plan {
	steps := [
		Step{
			id:                 'step_1'
			action:             'analyze'
			description:        'Analyze the task: ${task.description}'
			depends_on:         []
			status:             .pending
			estimated_duration: 15
		}
		Step{
			id:                 'step_2'
			action:             'plan'
			description:        'Create execution plan'
			depends_on:         ['step_1']
			status:             .pending
			estimated_duration: 20
		}
		Step{
			id:                 'step_3'
			action:             'execute'
			description:        'Execute the plan'
			depends_on:         ['step_2']
			status:             .pending
			estimated_duration: 30
		},
	]

	return Plan{
		task_id:                  task.id
		goal:                     task.description
		steps:                    steps
		confidence:               0.5
		created_at:               time.now().unix_milli()
		estimated_total_duration: 65
	}
}

// get_plan retrieves a stored plan
pub fn (p &Planner) get_plan(task_id string) ?Plan {
	return p.plans[task_id] or { return none }
}

// update_step_status updates the status of a step
pub fn (mut p Planner) update_step_status(task_id string, step_id string, status StepStatus) ! {
	if mut plan := p.plans[task_id] {
		mut steps := plan.steps
		for i, mut step in steps {
			if step.id == step_id {
				steps[i] = Step{
					...step
					status: status
				}
				p.plans[task_id] = Plan{
					...plan
					steps: steps
				}
				return
			}
		}
		return error('Step not found: ${step_id}')
	}
	return error('Plan not found: ${task_id}')
}

// get_execution_order returns steps in dependency order
pub fn (p &Planner) get_execution_order(task_id string) ![]Step {
	plan := p.plans[task_id] or { return error('Plan not found') }

	// Simple topological sort
	mut result := []Step{}
	mut completed := map[string]bool{}
	mut steps_map := map[string]Step{}

	for step in plan.steps {
		steps_map[step.id] = step
	}

	for result.len < plan.steps.len {
		mut made_progress := false

		for step in plan.steps {
			if completed[step.id] { continue }

			// Check if all dependencies are completed
			mut deps_satisfied := true
			for dep in step.depends_on {
				if !completed[dep] {
					deps_satisfied = false
					break
				}
			}

			if deps_satisfied {
				result << step
				completed[step.id] = true
				made_progress = true
			}
		}

		if !made_progress {
			return error('Circular dependency detected')
		}
	}

	return result
}

// get_plan_progress returns completion percentage
pub fn (p &Planner) get_plan_progress(task_id string) f64 {
	plan := p.plans[task_id] or { return 0.0 }

	if plan.steps.len == 0 { return 0.0 }

	mut completed := 0
	for step in plan.steps {
		if step.status == .completed || step.status == .skipped {
			completed++
		}
	}

	return f64(completed) / f64(plan.steps.len) * 100.0
}

// delete_plan removes a plan
pub fn (mut p Planner) delete_plan(task_id string) {
	p.plans.delete(task_id)
}

// list_plans returns all plan IDs
pub fn (p &Planner) list_plans() []string {
	return p.plans.keys()
}

// String returns string representation of Priority
pub fn (p Priority) str() string {
	return match p {
		.low { 'low' }
		.medium { 'medium' }
		.high { 'high' }
		.critical { 'critical' }
	}
}

// String returns string representation of StepStatus
pub fn (s StepStatus) str() string {
	return match s {
		.pending { 'pending' }
		.in_progress { 'in_progress' }
		.completed { 'completed' }
		.failed { 'failed' }
		.skipped { 'skipped' }
	}
}
