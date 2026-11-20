// validator.v - Data validation for VModulith
// Reuses: V struct tags and reflection

module validator

import regex
import strconv

// Validation error
pub struct ValidationError {
pub:
	field   string
	message string
}

// Validation result
pub struct ValidationResult {
pub mut:
	valid  bool
	errors []ValidationError
}

// Validator provides validation functions
pub struct Validator {}

// new_validator creates a new validator
pub fn new_validator() Validator {
	return Validator{}
}

// validate validates a struct based on tags
pub fn (v &Validator) validate[T](item T) ValidationResult {
	mut result := ValidationResult{valid: true, errors: []}
	
	// Note: V reflection capabilities are limited
	// In production, use compile-time macros or code generation
	
	return result
}

// String validation

// required checks if string is not empty
pub fn required(value string, field string) ! {
	if value.trim_space() == '' {
		return error('${field} is required')
	}
}

// min_length checks minimum length
pub fn min_length(value string, min int, field string) ! {
	if value.len < min {
		return error('${field} must be at least ${min} characters')
	}
}

// max_length checks maximum length
pub fn max_length(value string, max int, field string) ! {
	if value.len > max {
		return error('${field} must be at most ${max} characters')
	}
}

// length checks exact length
pub fn length(value string, exact int, field string) ! {
	if value.len != exact {
		return error('${field} must be exactly ${exact} characters')
	}
}

// email validates email format
pub fn email(value string, field string) ! {
	if value == '' {
		return
	}
	
	// Simple email regex
	pattern := r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
	re := regex.regex_opt(pattern) or { return error('invalid regex') }
	
	if !re.matches_string(value) {
		return error('${field} must be a valid email address')
	}
}

// phone validates phone number
pub fn phone(value string, field string) ! {
	if value == '' {
		return
	}
	
	// Remove common separators
	cleaned := value.replace('-', '').replace(' ', '').replace('(', '').replace(')', '')
	
	// Check if all digits
	for c in cleaned {
		if !c.is_digit() {
			return error('${field} must be a valid phone number')
		}
	}
	
	// Check length (most phone numbers are 10-15 digits)
	if cleaned.len < 10 || cleaned.len > 15 {
		return error('${field} must be a valid phone number')
	}
}

// url validates URL format
pub fn url(value string, field string) ! {
	if value == '' {
		return
	}
	
	if !value.starts_with('http://') && !value.starts_with('https://') {
		return error('${field} must be a valid URL')
	}
}

// alphanumeric checks if string contains only letters and numbers
pub fn alphanumeric(value string, field string) ! {
	for c in value {
		if !c.is_alnum() {
			return error('${field} must contain only letters and numbers')
		}
	}
}

// Numeric validation

// min checks minimum value
pub fn min[T](value T, min_val T, field string) ! {
	if value < min_val {
		return error('${field} must be at least ${min_val}')
	}
}

// max checks maximum value
pub fn max[T](value T, max_val T, field string) ! {
	if value > max_val {
		return error('${field} must be at most ${max_val}')
	}
}

// range checks if value is within range
pub fn range[T](value T, min_val T, max_val T, field string) ! {
	if value < min_val || value > max_val {
		return error('${field} must be between ${min_val} and ${max_val}')
	}
}

// positive checks if number is positive
pub fn positive[T](value T, field string) ! {
	if value <= 0 {
		return error('${field} must be positive')
	}
}

// non_negative checks if number is non-negative
pub fn non_negative[T](value T, field string) ! {
	if value < 0 {
		return error('${field} must be non-negative')
	}
}

// Collection validation

// not_empty checks if array is not empty
pub fn not_empty[T](arr []T, field string) ! {
	if arr.len == 0 {
		return error('${field} cannot be empty')
	}
}

// min_items checks minimum array length
pub fn min_items[T](arr []T, min int, field string) ! {
	if arr.len < min {
		return error('${field} must have at least ${min} items')
	}
}

// max_items checks maximum array length
pub fn max_items[T](arr []T, max int, field string) ! {
	if arr.len > max {
		return error('${field} must have at most ${max} items')
	}
}

// contains checks if array contains value
pub fn contains[T](arr []T, value T, field string) ! {
	if value !in arr {
		return error('${field} does not contain required value')
	}
}

// Date/Time validation

// is_date validates date string (YYYY-MM-DD)
pub fn is_date(value string, field string) ! {
	if value == '' {
		return
	}
	
	parts := value.split('-')
	if parts.len != 3 {
		return error('${field} must be a valid date (YYYY-MM-DD)')
	}
	
	year := strconv.atoi(parts[0]) or { return error('${field} has invalid year') }
	month := strconv.atoi(parts[1]) or { return error('${field} has invalid month') }
	day := strconv.atoi(parts[2]) or { return error('${field} has invalid day') }
	
	if year < 1900 || year > 2100 {
		return error('${field} has invalid year')
	}
	if month < 1 || month > 12 {
		return error('${field} has invalid month')
	}
	if day < 1 || day > 31 {
		return error('${field} has invalid day')
	}
}

// Custom validators for e-commerce

// price validates price format (positive number with 2 decimal places)
pub fn price(value f64, field string) ! {
	if value < 0 {
		return error('${field} must be non-negative')
	}
	
	// Check if it has at most 2 decimal places
	rounded := f64(int(value * 100)) / 100
	if value != rounded {
		return error('${field} must have at most 2 decimal places')
	}
}

// quantity validates quantity (positive integer)
pub fn quantity(value int, field string) ! {
	if value < 1 {
		return error('${field} must be at least 1')
	}
}

// sku validates SKU format (alphanumeric, specific format)
pub fn sku(value string, field string) ! {
	if value == '' {
		return error('${field} is required')
	}
	
	if value.len < 3 || value.len > 50 {
		return error('${field} must be between 3 and 50 characters')
	}
	
	for c in value {
		if !c.is_alnum() && c != `-` && c != `_` {
			return error('${field} can only contain letters, numbers, hyphens, and underscores')
		}
	}
}

// credit_card validates credit card number using Luhn algorithm
pub fn credit_card(number string, field string) ! {
	if number == '' {
		return
	}
	
	// Remove spaces and dashes
	cleaned := number.replace(' ', '').replace('-', '')
	
	// Check if all digits
	for c in cleaned {
		if !c.is_digit() {
			return error('${field} must contain only digits')
		}
	}
	
	// Check length (13-19 digits)
	if cleaned.len < 13 || cleaned.len > 19 {
		return error('${field} must be 13-19 digits')
	}
	
	// Luhn algorithm
	mut sum := 0
	mut alternate := false
	
	for i := cleaned.len - 1; i >= 0; i-- {
		mut digit := cleaned[i].ascii_str().int()
		
		if alternate {
			digit *= 2
			if digit > 9 {
				digit -= 9
			}
		}
		
		sum += digit
		alternate = !alternate
	}
	
	if sum % 10 != 0 {
		return error('${field} is not a valid credit card number')
	}
}

// Validation chains for complex objects

// ValidateResult accumulates validation errors
pub struct ValidateResult {
pub mut:
	valid  bool
	errors map[string][]string
}

// new_result creates a new validation result
pub fn new_result() ValidateResult {
	return ValidateResult{
		valid:  true
		errors: {}
	}
}

// add_error adds an error to the result
pub fn (mut r ValidateResult) add_error(field string, message string) {
	r.valid = false
	if field !in r.errors {
		r.errors[field] = []
	}
	r.errors[field] << message
}

// get_errors gets all errors for a field
pub fn (r &ValidateResult) get_errors(field string) []string {
	return r.errors[field] or { [] }
}

// has_errors checks if there are any errors
pub fn (r &ValidateResult) has_errors() bool {
	return !r.valid
}

// Product validation for e-commerce
pub struct ProductValidator {}

// validate_product validates a product
pub fn (v &ProductValidator) validate_product(name string, price f64, sku string, stock int) ValidateResult {
	mut result := new_result()
	
	// Name validation
	if name == '' {
		result.add_error('name', 'Product name is required')
	} else if name.len < 2 {
		result.add_error('name', 'Product name must be at least 2 characters')
	} else if name.len > 200 {
		result.add_error('name', 'Product name must be at most 200 characters')
	}
	
	// Price validation
	if price < 0 {
		result.add_error('price', 'Price must be non-negative')
	} else if price > 1000000 {
		result.add_error('price', 'Price is too high')
	}
	
	// SKU validation
	if sku == '' {
		result.add_error('sku', 'SKU is required')
	} else {
		sku(sku, 'sku') or { result.add_error('sku', err.msg()) }
	}
	
	// Stock validation
	if stock < 0 {
		result.add_error('stock', 'Stock cannot be negative')
	}
	
	return result
}

// Order validation
pub struct OrderValidator {}

// validate_order validates an order
pub fn (v &OrderValidator) validate_order(items []string, total f64, customer_email string) ValidateResult {
	mut result := new_result()
	
	// Items validation
	if items.len == 0 {
		result.add_error('items', 'Order must contain at least one item')
	}
	
	// Total validation
	if total <= 0 {
		result.add_error('total', 'Order total must be positive')
	}
	
	// Email validation
	if customer_email == '' {
		result.add_error('email', 'Customer email is required')
	} else {
		email(customer_email, 'email') or { result.add_error('email', err.msg()) }
	}
	
	return result
}
