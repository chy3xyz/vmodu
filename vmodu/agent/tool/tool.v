// tool.v - Agent Tool interface and implementations

module tool

// Tool is the interface for agent tools
pub interface Tool {
	name() string
	description() string
	run(input string) string
}

// BaseTool provides common functionality for tools
pub struct BaseTool {
pub:
	tool_name        string
	tool_description string
}

// name returns the tool name
pub fn (t &BaseTool) name() string {
	return t.tool_name
}

// description returns the tool description
pub fn (t &BaseTool) description() string {
	return t.tool_description
}

// ToolRegistry manages available tools
pub struct ToolRegistry {
pub mut:
	tools map[string]Tool
}

// new_registry creates a new ToolRegistry
pub fn new_registry() ToolRegistry {
	return ToolRegistry{
		tools: {}
	}
}

// register adds a tool to the registry
pub fn (mut r ToolRegistry) register(t Tool) {
	r.tools[t.name()] = t
}

// get retrieves a tool by name
pub fn (r &ToolRegistry) get(name string) ?Tool {
	return r.tools[name] or { return none }
}

// list returns all tool names
pub fn (r &ToolRegistry) list() []string {
	mut names := []string{cap: r.tools.len}
	for name, _ in r.tools {
		names << name
	}
	names.sort()
	return names
}

// remove removes a tool by name
pub fn (mut r ToolRegistry) remove(name string) {
	r.tools.delete(name)
}

// Example tool implementations

// EchoTool echoes the input
pub struct EchoTool {
	BaseTool
}

// new_echo_tool creates a new EchoTool
pub fn new_echo_tool() EchoTool {
	return EchoTool{
		BaseTool: BaseTool{
			tool_name:        'echo'
			tool_description: 'Echoes the input back'
		}
	}
}

// run executes the tool
pub fn (t &EchoTool) run(input string) string {
	return 'Echo: ${input}'
}

// CalculatorTool performs basic calculations
pub struct CalculatorTool {
	BaseTool
}

// new_calculator_tool creates a new CalculatorTool
pub fn new_calculator_tool() CalculatorTool {
	return CalculatorTool{
		BaseTool: BaseTool{
			tool_name:        'calculator'
			tool_description: 'Performs basic calculations'
		}
	}
}

// run executes the calculation
pub fn (t &CalculatorTool) run(input string) string {
	// Simple parser for "1 + 2" format
	parts := input.split(' ')
	if parts.len != 3 {
		return 'Invalid format. Use: number operator number'
	}
	
	a := parts[0].f64()
	op := parts[1]
	b := parts[2].f64()
	
	match op {
		'+' { return (a + b).str() }
		'-' { return (a - b).str() }
		'*' { return (a * b).str() }
		'/' { return (a / b).str() }
		else { return 'Unknown operator: ${op}' }
	}
}
