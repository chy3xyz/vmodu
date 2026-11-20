// template.v - Template Engine for VModulith
// Reuses: strings from V standard library

module template

import strings
import os

// Template represents a compiled template
pub struct Template {
pub mut:
	name     string
	source   string
	partials map[string]Template
}

// Engine manages templates
pub struct Engine {
pub mut:
	templates map[string]Template
	partials  map[string]Template
	globals   map[string]string
}

// new_engine creates a new template engine
pub fn new_engine() &Engine {
	return &Engine{
		templates: {}
		partials:  {}
		globals:   {}
	}
}

// set_global sets a global variable
pub fn (mut e Engine) set_global(key string, value string) {
	e.globals[key] = value
}

// load_template loads a template from string
pub fn (mut e Engine) load_template(name string, source string) {
	e.templates[name] = Template{
		name:     name
		source:   source
		partials: {}
	}
}

// load_template_from_file loads a template from file
pub fn (mut e Engine) load_template_from_file(name string, path string) ! {
	source := os.read_file(path)!
	e.load_template(name, source)
}

// register_partial registers a partial template
pub fn (mut e Engine) register_partial(name string, source string) {
	e.partials[name] = Template{
		name:   name
		source: source
	}
}

// render renders a template with data
pub fn (e &Engine) render(name string, data map[string]string) !string {
	template := e.templates[name] or { return error('template not found: ${name}') }
	
	mut result := template.source
	
	// Merge globals with data
	mut context := e.globals.clone()
	for key, value in data {
		context[key] = value
	}
	
	// Process partials first
	result = e.process_partials(result)
	
	// Process conditionals
	result = e.process_conditionals(result, context)
	
	// Process loops
	result = e.process_loops(result, context)
	
	// Process variables
	result = e.process_variables(result, context)
	
	return result
}

// process_variables replaces {{variable}} with values
fn (e &Engine) process_variables(template string, data map[string]string) string {
	mut result := template
	
	for key, value in data {
		placeholder := '{{${key}}}'
		result = result.replace(placeholder, value)
	}
	
	// Clean up unprocessed variables
	// (optional: leave them or replace with empty string)
	
	return result
}

// process_conditionals processes {{if condition}}...{{end}} blocks
fn (e &Engine) process_conditionals(template string, data map[string]string) string {
	mut result := template
	
	// Simple if/else processing
	// Format: {{if key}}...{{else}}...{{end}}
	
	for {
		start_idx := result.index('{{if ') or { break }
		end_idx := result.index('{{end}}') or { break }
		
		if start_idx >= end_idx {
			break
		}
		
		block := result[start_idx..end_idx + 7]  // include {{end}}
		
		// Extract condition
		cond_start := start_idx + 5
		cond_end := result.index_after('}}', cond_start)
		condition := result[cond_start..cond_end].trim_space()
		
		// Check condition
		condition_met := data[condition] != '' && data[condition] != 'false'
		
		// Extract content
		content_start := cond_end + 2
		content_end := end_idx
		content := result[content_start..content_end]
		
		// Handle else
		mut if_content := content
		mut else_content := ''
		
		if else_idx := content.index('{{else}}') {
			if_content = content[..else_idx]
			else_content = content[else_idx + 8..]
		}
		
		// Replace block
		replacement := if condition_met { if_content } else { else_content }
		result = result.replace(block, replacement)
	}
	
	return result
}

// process_loops processes {{for item in items}}...{{end}} blocks
fn (e &Engine) process_loops(template string, data map[string]string) string {
	// Simplified loop processing
	// In production, this would need more sophisticated parsing
	return template
}

// process_partials processes {{>partial_name}} includes
fn (e &Engine) process_partials(template string) string {
	mut result := template
	
	for {
		start_idx := result.index('{{>') or { break }
		end_idx := result.index_after('}}', start_idx)
		
		if end_idx <= start_idx {
			break
		}
		
		placeholder := result[start_idx..end_idx + 2]
		partial_name := result[start_idx + 3..end_idx].trim_space()
		
		if partial := e.partials[partial_name] {
			result = result.replace(placeholder, partial.source)
		} else {
			result = result.replace(placeholder, '')
		}
	}
	
	return result
}

// Email templates for e-commerce
pub struct EmailTemplates {
pub mut:
	engine &Engine
}

// new_email_templates creates email template manager
pub fn new_email_templates() &EmailTemplates {
	mut engine := new_engine()
	
	// Register common partials
	engine.register_partial('header', '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>{{subject}}</title>
</head>
<body>
    <div style="max-width: 600px; margin: 0 auto;">
        <header style="background: #f5f5f5; padding: 20px; text-align: center;">
            <h1>{{shop_name}}</h1>
        </header>
')
	
	engine.register_partial('footer', '
        <footer style="background: #f5f5f5; padding: 20px; text-align: center; margin-top: 30px;">
            <p>&copy; {{year}} {{shop_name}}. All rights reserved.</p>
            <p>{{shop_address}}</p>
        </footer>
    </div>
</body>
</html>
')
	
	// Set globals
	engine.set_global('shop_name', 'My Shop')
	engine.set_global('year', '${time.now().year}')
	
	return &EmailTemplates{engine: engine}
}

// load_default_templates loads default email templates
pub fn (mut t EmailTemplates) load_default_templates() {
	// Order confirmation email
	t.engine.load_template('order_confirmation', '{{>header}}
<main style="padding: 20px;">
    <h2>Thank you for your order, {{customer_name}}!</h2>
    <p>Your order #{{order_number}} has been confirmed.</p>
    
    <div style="background: #f9f9f9; padding: 15px; margin: 20px 0;">
        <h3>Order Details</h3>
        <p><strong>Total:</strong> ${{order_total}}</p>
        <p><strong>Status:</strong> {{order_status}}</p>
    </div>
    
    {{if tracking_number}}
    <p>Track your order: <a href="{{tracking_url}}">{{tracking_number}}</a></p>
    {{end}}
</main>
{{>footer}}')
	
	// Shipping notification email
	t.engine.load_template('shipping_notification', '{{>header}}
<main style="padding: 20px;">
    <h2>Your order has shipped!</h2>
    <p>Hi {{customer_name}},</p>
    <p>Your order #{{order_number}} is on its way!</p>
    
    <div style="background: #f9f9f9; padding: 15px; margin: 20px 0;">
        <p><strong>Tracking Number:</strong> {{tracking_number}}</p>
        <p><strong>Carrier:</strong> {{carrier}}</p>
        <p><a href="{{tracking_url}}" style="display: inline-block; background: #007bff; color: white; padding: 10px 20px; text-decoration: none;">Track Your Package</a></p>
    </div>
</main>
{{>footer}}')
	
	// Password reset email
	t.engine.load_template('password_reset', '{{>header}}
<main style="padding: 20px;">
    <h2>Password Reset Request</h2>
    <p>Hi {{customer_name}},</p>
    <p>We received a request to reset your password. Click the link below to reset it:</p>
    
    <p style="text-align: center; margin: 30px 0;">
        <a href="{{reset_url}}" style="display: inline-block; background: #dc3545; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px;">Reset Password</a>
    </p>
    
    <p>If you didn't request this, please ignore this email.</p>
    <p>This link expires in {{expiry_hours}} hours.</p>
</main>
{{>footer}}')
	
	// Welcome email
	t.engine.load_template('welcome', '{{>header}}
<main style="padding: 20px;">
    <h2>Welcome to {{shop_name}}!</h2>
    <p>Hi {{customer_name}},</p>
    <p>Thank you for joining us. We\'re excited to have you as a customer!</p>
    
    <div style="text-align: center; margin: 30px 0;">
        <a href="{{shop_url}}" style="display: inline-block; background: #28a745; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px;">Start Shopping</a>
    </div>
    
    <p>Here\'s what you can do:</p>
    <ul>
        <li>Browse our latest products</li>
        <li>Save items to your wishlist</li>
        <li>Track your orders</li>
    </ul>
</main>
{{>footer}}')
}

// SMS templates for e-commerce
pub struct SMSTemplates {
pub mut:
	templates map[string]string
}

// new_sms_templates creates SMS template manager
pub fn new_sms_templates() SMSTemplates {
	mut templates := SMSTemplates{
		templates: {}
	}
	
	// Load default templates
	templates.templates['order_confirmation'] = 'Hi {{customer_name}}! Your order #{{order_number}} for ${{order_total}} has been confirmed. Track at: {{tracking_url}}'
	
	templates.templates['shipping_notification'] = 'Good news! Your order #{{order_number}} has shipped. Track: {{tracking_url}}'
	
	templates.templates['delivery_reminder'] = 'Your order #{{order_number}} will be delivered today. Be ready!'
	
	templates.templates['verification_code'] = 'Your {{shop_name}} verification code is: {{code}}. Valid for {{expiry_minutes}} minutes.'
	
	templates.templates['password_reset'] = '{{shop_name}} password reset code: {{code}}. Valid for {{expiry_minutes}} minutes.'
	
	return templates
}

// render renders an SMS template
pub fn (s &SMSTemplates) render(name string, data map[string]string) !string {
	template := s.templates[name] or { return error('SMS template not found: ${name}') }
	
	mut result := template
	for key, value in data {
		result = result.replace('{{${key}}}', value)
	}
	
	return result
}

// Helper functions

// truncate_string truncates a string to max length
fn truncate_string(s string, max_len int) string {
	if s.len <= max_len {
		return s
	}
	return s[..max_len] + '...'
}

// format_currency formats a number as currency
fn format_currency(amount f64, symbol string) string {
	return '${symbol}${amount:.2f}'
}

// format_date formats a timestamp as date string
fn format_date(timestamp i64, format string) string {
	// Simplified date formatting
	return '${timestamp}'
}
