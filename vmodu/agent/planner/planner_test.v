// planner_test.v - Unit tests for planner module

module planner

import vmodu.agent.tool

fn test_new_planner() {
	mut p := new_planner()
	
	assert p.tools.len == 0
	assert p.max_steps == max_plan_steps
	assert p.temperature == default_temperature
}

fn test_register_tool() {
	mut p := new_planner()
	echo_tool := tool.new_echo_tool()
	
	p.register_tool(echo_tool)
	
	assert p.tools.len == 1
	assert p.tools[0].name() == 'echo'
}

fn test_create_plan_swap() {
	mut p := new_planner()
	
	task := Task{
		id:          'task-1'
		description: 'Swap 100 USDC for ETH'
		context:     {}
		deadline_ms: 0
	}
	
	plan := p.create_plan(task)
	
	assert plan.task_id == 'task-1'
	assert plan.steps.len == 4 // analyze, check_balance, execute_swap, verify
	assert plan.steps[0].tool_name == 'market_analyzer'
	assert plan.steps[2].tool_name == 'swap_tool'
}

fn test_create_plan_transfer() {
	mut p := new_planner()
	
	task := Task{
		id:          'task-2'
		description: 'Transfer 50 USDT to address'
		context:     {}
		deadline_ms: 0
	}
	
	plan := p.create_plan(task)
	
	assert plan.task_id == 'task-2'
	assert plan.steps.len == 3 // validate_address, check_balance, send_transaction
	assert plan.steps[0].action == 'validate_address'
}

fn test_create_plan_query() {
	mut p := new_planner()
	
	task := Task{
		id:          'task-3'
		description: 'Get my balance'
		context:     {}
		deadline_ms: 0
	}
	
	plan := p.create_plan(task)
	
	assert plan.steps.len == 1
	assert plan.steps[0].action == 'query_data'
}

fn test_create_plan_unknown() {
	mut p := new_planner()
	
	task := Task{
		id:          'task-4'
		description: 'Do something unknown'
		context:     {}
		deadline_ms: 0
	}
	
	plan := p.create_plan(task)
	
	// Should generate a default analysis step
	assert plan.steps.len == 1
	assert plan.steps[0].action == 'analyze'
}

fn test_format_plan() {
	plan := Plan{
		task_id:        'test-task'
		steps:          [
			PlanStep{
				step_number: 1
				action:      'test_action'
				tool_name:   'test_tool'
				input:       'test_input'
				depends_on:  []int{}
				reasoning:   'test reasoning'
			},
		]
		created_at:     0
		estimated_cost: 0.001
	}
	
	output := format_plan(plan)
	
	assert output.contains('Plan for task: test-task')
	assert output.contains('1. [test_tool] test_action')
	assert output.contains('Input: test_input')
}

fn test_get_plan_result() {
	ctx := ExecutionContext{
		plan: Plan{
			task_id: 'test'
			steps:   [
				PlanStep{step_number: 1, action: 'step1', tool_name: 't1', input: '', depends_on: []int{}, reasoning: ''},
				PlanStep{step_number: 2, action: 'step2', tool_name: 't2', input: '', depends_on: []int{}, reasoning: ''},
			]
		}
		current_step: 2
		results:      {
			1: 'success1'
			2: 'success2'
		}
		variables:    {}
		is_complete:  true
	}
	
	result := get_plan_result(ctx)
	
	assert result.success == true
	assert result.total_steps == 2
	assert result.completed_steps == 2
	assert result.final_output == 'success2'
}

fn test_get_plan_result_with_errors() {
	ctx := ExecutionContext{
		plan: Plan{
			task_id: 'test'
			steps:   [
				PlanStep{step_number: 1, action: 'step1', tool_name: 't1', input: '', depends_on: []int{}, reasoning: ''},
				PlanStep{step_number: 2, action: 'step2', tool_name: 't2', input: '', depends_on: []int{}, reasoning: ''},
			]
		}
		current_step: 2
		results:      {
			1: 'success1'
			2: 'error: something failed'
		}
		variables:    {}
		is_complete:  true
	}
	
	result := get_plan_result(ctx)
	
	assert result.completed_steps == 1 // Only first step succeeded
	assert result.total_steps == 2
}
