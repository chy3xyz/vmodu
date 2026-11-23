// payment.v - Payment Gateway Integration for VModulith
// Supports: Alipay, WeChat Pay, Stripe, PayPal
//
// EXPERIMENTAL: Not a production payment gateway. Provider signing (e.g. Alipay RSA)
// and live settlement paths are incomplete stubs — do not use as a default prod path.

module payment

import net.http
import net.urllib
import json2
import crypto.hmac
import crypto.sha256
import encoding.base64
import time
import rand

// Payment providers
pub enum Provider {
	alipay
	wechat_pay
	stripe
	paypal
}

// Payment status
pub enum PaymentStatus {
	pending
	processing
	success
	failed
	cancelled
	refunded
}

// Config for payment gateway
pub struct Config {
pub:
	provider    Provider
	app_id      string
	app_secret  string
	merchant_id string
	public_key  string
	private_key string
	sandbox     bool = true
	notify_url  string
	return_url  string
}

// Client for payment operations
pub struct Client {
pub:
	config Config
}

// new_client creates a new payment client
pub fn new_client(config Config) Client {
	return Client{ config: config }
}

// Order represents a payment order
pub struct Order {
pub:
	id         string
	amount     f64
	currency   string = 'CNY'
	subject    string
	body       string
	order_id   string // Merchant order ID
	notify_url string
	return_url string
	extra      map[string]string
}

// PaymentResult contains payment result
pub struct PaymentResult {
pub:
	success    bool
	order_id   string
	payment_id string
	amount     f64
	currency   string
	status     PaymentStatus
	pay_url    string            // URL for user to complete payment
	params     map[string]string // Additional parameters
}

// create_payment creates a payment order
pub fn (c &Client) create_payment(order Order) !PaymentResult {
	match c.config.provider {
		.alipay {
			return c.create_alipay_payment(order)
		}
		.wechat_pay {
			return c.create_wechat_payment(order)
		}
		.stripe {
			return c.create_stripe_payment(order)
		}
		.paypal {
			return c.create_paypal_payment(order)
		}
	}
}

// query_payment queries payment status
pub fn (c &Client) query_payment(order_id string) !PaymentResult {
	match c.config.provider {
		.alipay {
			return c.query_alipay_payment(order_id)
		}
		.wechat_pay {
			return c.query_wechat_payment(order_id)
		}
		.stripe {
			return c.query_stripe_payment(order_id)
		}
		.paypal {
			return c.query_paypal_payment(order_id)
		}
	}
}

// refund requests a refund
pub fn (c &Client) refund(order_id string, amount f64, reason string) !RefundResult {
	match c.config.provider {
		.alipay {
			return c.refund_alipay(order_id, amount, reason)
		}
		.wechat_pay {
			return c.refund_wechat(order_id, amount, reason)
		}
		.stripe {
			return c.refund_stripe(order_id, amount, reason)
		}
		.paypal {
			return c.refund_paypal(order_id, amount, reason)
		}
	}
}

// RefundResult contains refund result
pub struct RefundResult {
pub:
	success   bool
	refund_id string
	order_id  string
	amount    f64
	status    string
}

// Alipay implementation
fn (c &Client) create_alipay_payment(order Order) !PaymentResult {
	// Build Alipay request
	mut params := {
		'app_id':      c.config.app_id
		'method':      'alipay.trade.page.pay'
		'format':      'JSON'
		'charset':     'utf-8'
		'sign_type':   'RSA2'
		'timestamp':   time.now().format_ss()
		'version':     '1.0'
		'notify_url':  order.notify_url
		'return_url':  order.return_url
		'biz_content': json2.encode({
			'out_trade_no': order.order_id
			'total_amount': '${order.amount}'
			'subject':      order.subject
			'product_code': 'FAST_INSTANT_TRADE_PAY'
		}, escape_unicode: true, time_as_unix: true)
	}

	// Sign the request
	params['sign'] = c.sign_alipay(params)

	// Build payment URL
	gateway := if c.config.sandbox {
		'https://openapi.alipaydev.com/gateway.do'
	} else {
		'https://openapi.alipay.com/gateway.do'
	}

	pay_url := '${gateway}?' + encode_params(params)

	return PaymentResult{
		success:    true
		order_id:   order.order_id
		payment_id: ''
		amount:     order.amount
		currency:   order.currency
		status:     .pending
		pay_url:    pay_url
		params:     params
	}
}

fn (c &Client) query_alipay_payment(order_id string) !PaymentResult {
	mut params := {
		'app_id':      c.config.app_id
		'method':      'alipay.trade.query'
		'format':      'JSON'
		'charset':     'utf-8'
		'sign_type':   'RSA2'
		'timestamp':   time.now().format_ss()
		'version':     '1.0'
		'biz_content': json2.encode({
			'out_trade_no': order_id
		}, escape_unicode: true, time_as_unix: true)
	}

	params['sign'] = c.sign_alipay(params)

	// Send request
	resp := c.send_post(params)!

	// Parse response
	return c.parse_alipay_response(resp)
}

fn (c &Client) refund_alipay(order_id string, amount f64, reason string) !RefundResult {
	mut params := {
		'app_id':      c.config.app_id
		'method':      'alipay.trade.refund'
		'format':      'JSON'
		'charset':     'utf-8'
		'sign_type':   'RSA2'
		'timestamp':   time.now().format_ss()
		'version':     '1.0'
		'biz_content': json2.encode({
			'out_trade_no':  order_id
			'refund_amount': '${amount}'
			'refund_reason': reason
		}, escape_unicode: true, time_as_unix: true)
	}

	params['sign'] = c.sign_alipay(params)
	resp := c.send_post(params)!

	return RefundResult{
		success:   true
		refund_id: ''
		order_id:  order_id
		amount:    amount
		status:    'SUCCESS'
	}
}

fn (c &Client) sign_alipay(params map[string]string) string {
	// Sort parameters
	mut keys := params.keys()
	keys.sort()

	// Build string to sign
	mut parts := []string{}
	for key in keys {
		if key != 'sign' && params[key] != '' {
			parts << '${key}=${params[key]}'
		}
	}
	string_to_sign := parts.join('&')

	// Sign with RSA
	// In production, use proper RSA signing
	return base64.encode(hmac.new(c.config.private_key.bytes(), string_to_sign.bytes(), sha256.sum, sha256.block_size))
}

// WeChat Pay implementation
fn (c &Client) create_wechat_payment(order Order) !PaymentResult {
	mut params := {
		'appid':            c.config.app_id
		'mch_id':           c.config.merchant_id
		'nonce_str':        generate_nonce()
		'body':             order.subject
		'out_trade_no':     order.order_id
		'total_fee':        '${int(order.amount * 100)}' // Convert to cents
		'spbill_create_ip': '127.0.0.1'
		'notify_url':       order.notify_url
		'trade_type':       'NATIVE' // QR code payment
	}

	params['sign'] = c.sign_wechat(params)

	gateway := if c.config.sandbox {
		'https://api.mch.weixin.qq.com/sandboxnew/pay/unifiedorder'
	} else {
		'https://api.mch.weixin.qq.com/pay/unifiedorder'
	}

	return PaymentResult{
		success:  true
		order_id: order.order_id
		amount:   order.amount
		currency: order.currency
		status:   .pending
		pay_url:  '' // Will be code_url from response
		params:   params
	}
}

fn (c &Client) query_wechat_payment(order_id string) !PaymentResult {
	mut params := {
		'appid':        c.config.app_id
		'mch_id':       c.config.merchant_id
		'nonce_str':    generate_nonce()
		'out_trade_no': order_id
	}

	params['sign'] = c.sign_wechat(params)

	return PaymentResult{
		success:  false
		order_id: order_id
		status:   .pending
	}
}

fn (c &Client) refund_wechat(order_id string, amount f64, reason string) !RefundResult {
	return RefundResult{
		success:   false
		refund_id: ''
		order_id:  order_id
	}
}

fn (c &Client) sign_wechat(params map[string]string) string {
	// Sort parameters
	mut keys := params.keys()
	keys.sort()

	// Build string to sign
	mut parts := []string{}
	for key in keys {
		if key != 'sign' && params[key] != '' {
			parts << '${key}=${params[key]}'
		}
	}
	string_to_sign := parts.join('&') + '&key=${c.config.app_secret}'

	return sha256.hexhash(string_to_sign).to_upper()
}

// Stripe implementation
fn (c &Client) create_stripe_payment(order Order) !PaymentResult {
	mut form := {
		'amount':             '${int(order.amount * 100)}' // Convert to cents
		'currency':           order.currency.to_lower()
		'description':        order.subject
		'metadata[order_id]': order.order_id
	}

	headers := http.new_custom_header_from_map({
		'Authorization': 'Bearer ${c.config.app_secret}'
		'Content-Type':  'application/x-www-form-urlencoded'
	})!

	gateway := if c.config.sandbox {
		'https://api.stripe.com/v1/payment_intents'
	} else {
		'https://api.stripe.com/v1/payment_intents'
	}

	mut req := http.new_request(.post, gateway, encode_form(form))
	req.header = headers

	resp := req.do()!

	return PaymentResult{
		success:  resp.status_code == 200
		order_id: order.order_id
		amount:   order.amount
		currency: order.currency
		status:   .pending
		pay_url:  ''
		params:   {}
	}
}

fn (c &Client) query_stripe_payment(order_id string) !PaymentResult {
	return PaymentResult{
		success:  false
		order_id: order_id
		status:   .pending
	}
}

fn (c &Client) refund_stripe(order_id string, amount f64, reason string) !RefundResult {
	return RefundResult{
		success:   false
		refund_id: ''
		order_id:  order_id
	}
}

// PayPal implementation
fn (c &Client) create_paypal_payment(order Order) !PaymentResult {
	return PaymentResult{
		success:  false
		order_id: order.order_id
	}
}

fn (c &Client) query_paypal_payment(order_id string) !PaymentResult {
	return PaymentResult{
		success:  false
		order_id: order_id
	}
}

fn (c &Client) refund_paypal(order_id string, amount f64, reason string) !RefundResult {
	return RefundResult{
		success:   false
		refund_id: ''
		order_id:  order_id
	}
}

// Helper functions

fn generate_nonce() string {
	return '${time.now().unix()}${rand.intn(1000000)}'
}

fn encode_params(params map[string]string) string {
	mut parts := []string{}
	for key, value in params {
		parts << '${key}=${value}'
	}
	return parts.join('&')
}

fn (c &Client) send_post(params map[string]string) !http.Response {
	// Implementation depends on provider
	return http.Response{}
}

fn (c &Client) parse_alipay_response(resp http.Response) PaymentResult {
	// Parse Alipay response JSON
	return PaymentResult{
		success: false
		status:  .pending
	}
}

// Webhook handling

// WebhookHandler handles payment notifications
pub struct WebhookHandler {
pub:
	client &Client
}

// handle_alipay_notify handles Alipay async notification
pub fn (h &WebhookHandler) handle_alipay_notify(data map[string]string) !PaymentResult {
	// Verify signature
	sign := data['sign'] or { return error('missing sign') }

	mut params := data.clone()
	params.delete('sign')
	params.delete('sign_type')

	expected_sign := h.client.sign_alipay(params)
	if sign != expected_sign {
		return error('invalid signature')
	}

	// Parse result
	trade_status := data['trade_status'] or { '' }
	status := match trade_status {
		'TRADE_SUCCESS' { PaymentStatus.success }
		'TRADE_CLOSED' { PaymentStatus.cancelled }
		else { PaymentStatus.pending }
	}

	return PaymentResult{
		success:    status == .success
		order_id:   data['out_trade_no'] or { '' }
		payment_id: data['trade_no'] or { '' }
		amount:     data['total_amount'] or { '0' }.f64()
		status:     status
	}
}

// handle_wechat_notify handles WeChat Pay notification
pub fn (h &WebhookHandler) handle_wechat_notify(xml_data string) !PaymentResult {
	// Parse XML
	// Verify signature
	// Return result
	return PaymentResult{
		success: false
		status:  .pending
	}
}

// Payment utilities

// format_amount formats amount for display
pub fn format_amount(amount f64, currency string) string {
	symbol := match currency {
		'CNY' { '¥' }
		'USD' { '$' }
		'EUR' { '€' }
		'GBP' { '£' }
		'JPY' { '¥' }
		else { currency + ' ' }
	}
	return '${symbol}${amount:.2f}'
}

// generate_order_id generates a unique order ID
pub fn generate_order_id() string {
	return 'ORDER${time.now().custom_format('YYYYMMdd')}${rand.intn(1000000) or { 0 }:06}'
}


fn encode_form(form map[string]string) string {
	mut parts := []string{}
	for k, v in form {
		parts << '${urllib.query_escape(k)}=${urllib.query_escape(v)}'
	}
	return parts.join('&')
}
