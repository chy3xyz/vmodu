// 06-veb-shop.v - E-commerce API with veb
// Demonstrates veb integration with VModulith modules

module main

import veb
import json2
import vmodu.infra.db.sql as db
import vmodu.infra.cache as cache
import vmodu.infra.auth as auth
import vmodu.infra.validator as validator

// Product represents a product
pub struct Product {
	id          string @[json: 'id']
	name        string @[json: 'name']
	description string @[json: 'description']
	price       f64    @[json: 'price']
	stock       int    @[json: 'stock']
	category    string @[json: 'category']
}

pub struct LoginCreds {
	email    string @[json: 'email']
	password string @[json: 'password']
}

pub struct CartItemReq {
	product_id string @[json: 'product_id']
	quantity   int    @[json: 'quantity']
}

pub struct CartItem {
	product_id string
	quantity   int
}

pub struct Cart {
mut:
	items []CartItem
}

// ShopApp is the shop application
pub struct ShopApp {
veb.Controller
mut:
	db_pool    &db.Pool
	redis      &cache.RedisClient
	jwt        auth.JWTManager
}

// new_shop_app creates a new shop app
pub fn new_shop_app() !&ShopApp {
	// Initialize database
	mut pool := db.new_pool(db.Config{
		db_type:  .sqlite
		database: 'shop.db'
	})!
	
	// Initialize Redis
	mut redis := cache.new_redis_client(cache.RedisConfig{
		host: 'localhost'
		port: 6379
	})!
	
	// Initialize JWT
	jwt := auth.new_jwt_manager(auth.JWTConfig{
		secret:     'your-secret-key'
		issuer:     'shop.example.com'
		access_ttl: 3600
	})
	
	return &ShopApp{
		db_pool: pool
		redis:   redis
		jwt:     jwt
	}
}

// get_products handles GET /api/products
pub fn (mut app ShopApp) get_products(mut ctx veb.Context) veb.Result {
	// Try cache first
	cached := app.redis.get('products:all') or { '' }
	if cached != '' {
		return ctx.text(cached).set_header('X-Cache', 'HIT')
	}
	
	// Get from database
	mut repo := db.new_repository[Product](app.db_pool)
	products := repo.find_all() or {
		ctx.res.set_status(500)
		return ctx.json({'error': 'database error'})
	}
	
	// Cache result
	products_json := json2.encode(products, escape_unicode: true, time_as_unix: true)
	app.redis.set('products:all', products_json, 300)!  // Cache 5 minutes
	
	return ctx.json(products)
}

// get_product handles GET /api/products/:id
pub fn (mut app ShopApp) get_product(mut ctx veb.Context) veb.Result {
	id := ctx.param('id')
	
	// Try cache first
	cache_key := 'product:${id}'
	cached := app.redis.get(cache_key) or { '' }
	if cached != '' {
		return ctx.text(cached).set_header('X-Cache', 'HIT')
	}
	
	// Get from database
	mut repo := db.new_repository[Product](app.db_pool)
	product := repo.find_by_id(id) or {
		ctx.res.set_status(404)
		return ctx.json({'error': 'product not found'})
	}
	
	// Cache result
	product_json := json2.encode(product, escape_unicode: true, time_as_unix: true)
	app.redis.set(cache_key, product_json, 600)!  // Cache 10 minutes
	
	return ctx.json(product)
}

// create_product handles POST /api/products (admin only)
pub fn (mut app ShopApp) create_product(mut ctx veb.Context) veb.Result {
	// Verify JWT
	auth_header := ctx.req.get_header('Authorization')
	token := extract_token(auth_header) or {
		ctx.res.set_status(401)
		return ctx.json({'error': 'unauthorized'})
	}
	
	payload := app.jwt.verify(token) or {
		ctx.res.set_status(401)
		return ctx.json({'error': 'invalid token'})
	}
	
	// Check admin role
	if !payload.roles.contains('admin') {
		ctx.res.set_status(403)
		return ctx.json({'error': 'forbidden'})
	}
	
	// Parse request
	mut product := Product{}
	product = json2.decode[Product](ctx.req.data) or {
		ctx.res.set_status(400)
		return ctx.json({'error': 'invalid JSON'})
	}
	
	// Validate
	mut result := validator.new_result()
	if product.name == '' {
		result.add_error('name', 'product name is required')
	}
	validator.price(product.price, 'price') or {
		result.add_error('price', err.msg())
	}
	
	if result.has_errors() {
		ctx.res.set_status(400)
		return ctx.json(result.errors)
	}
	
	// Save to database
	mut repo := db.new_repository[Product](app.db_pool)
	repo.save(product) or {
		ctx.res.set_status(500)
		return ctx.json({'error': 'failed to save product'})
	}
	
	// Invalidate cache
	app.redis.del('products:all')!
	
	ctx.res.set_status(201)
	return ctx.json(product)
}

// login handles POST /api/auth/login
pub fn (mut app ShopApp) login(mut ctx veb.Context) veb.Result {
	// Parse credentials
	mut creds := LoginCreds{}
	creds = json2.decode[LoginCreds](ctx.req.data) or {
		ctx.res.set_status(400)
		return ctx.json({'error': 'invalid JSON'})
	}
	
	// Validate
	validator.email(creds.email, 'email') or {
		ctx.res.set_status(400)
		return ctx.json({'error': 'invalid email'})
	}
	
	// In production, verify password against database
	// For demo, accept any password
	
	// Generate JWT
	token := app.jwt.generate('user_123', ['customer'], [
		'product:view',
		'order:create',
		'cart:modify',
	]) or {
		ctx.res.set_status(500)
		return ctx.json({'error': 'failed to generate token'})
	}
	
	return ctx.json({
		'token': token
		'type':  'Bearer'
	})
}

// get_cart handles GET /api/cart
pub fn (mut app ShopApp) get_cart(mut ctx veb.Context) veb.Result {
	user_id := ctx.get('user_id') or {
		ctx.res.set_status(401)
		return ctx.json({'error': 'unauthorized'})
	}
	
	// Get cart from Redis
	cart_key := 'cart:${user_id}'
	cart_data := app.redis.get(cart_key) or { '{}' }
	
	return ctx.text(cart_data)
}

// add_to_cart handles POST /api/cart/items
pub fn (mut app ShopApp) add_to_cart(mut ctx veb.Context) veb.Result {
	user_id := ctx.get('user_id') or {
		ctx.res.set_status(401)
		return ctx.json({'error': 'unauthorized'})
	}
	
	// Parse request
	mut item := CartItemReq{}
	item = json2.decode[CartItemReq](ctx.req.data) or {
		ctx.res.set_status(400)
		return ctx.json({'error': 'invalid JSON'})
	}
	
	// Validate quantity
	validator.quantity(item.quantity, 'quantity') or {
		ctx.res.set_status(400)
		return ctx.json({'error': err.msg()})
	}
	
	// Add to cart in Redis
	cart_key := 'cart:${user_id}'
	cart_json := app.redis.get(cart_key) or { '{}' }
	
	mut cart := Cart{}
	cart = json2.decode[Cart](cart_json) or { Cart{} }
	
	cart.items << CartItem{
		product_id: item.product_id
		quantity:   item.quantity
	}
	
	app.redis.set(cart_key, json2.encode(cart, escape_unicode: true, time_as_unix: true), 86400)!  // 24 hours
	
	return ctx.json(cart)
}

// Middleware

// auth_middleware creates auth middleware for veb
fn auth_middleware(jwt auth.JWTManager) fn (veb.Context) bool {
	return fn [jwt] (ctx veb.Context) bool {
		// Skip auth for public routes
		if ctx.req.url.starts_with('/api/auth/') {
			return true
		}
		
		auth_header := ctx.req.get_header('Authorization')
		if auth_header == '' {
			ctx.res.set_status(401)
			ctx.res.body = json2.encode({'error': 'unauthorized'}, escape_unicode: true, time_as_unix: true)
			return false
		}
		
		token := extract_token(auth_header) or {
			ctx.res.set_status(401)
			ctx.res.body = json2.encode({'error': 'invalid authorization header'}, escape_unicode: true, time_as_unix: true)
			return false
		}
		
		payload := jwt.verify(token) or {
			ctx.res.set_status(401)
			ctx.res.body = json2.encode({'error': 'invalid token'}, escape_unicode: true, time_as_unix: true)
			return false
		}
		
		// Store user info in context
		ctx.set('user_id', payload.sub)
		ctx.set('roles', json2.encode(payload.roles), escape_unicode: true, time_as_unix: true)
		
		return true
	}
}

// logging_middleware creates logging middleware
fn logging_middleware() fn (veb.Context) bool {
	return fn (ctx veb.Context) bool {
		start := veb.now()
		println('[${veb.now()}] ${ctx.req.method} ${ctx.req.url}')
		
		result := ctx.next()
		
		elapsed := veb.now() - start
		println('[${veb.now()}] ${ctx.req.method} ${ctx.req.url} - ${elapsed}ms')
		
		return result
	}
}

fn extract_token(auth_header string) !string {
	if !auth_header.starts_with('Bearer ') {
		return error('invalid format')
	}
	return auth_header[7..]
}

fn main() {
	mut app := new_shop_app() or {
		eprintln('Failed to initialize app: ${err}')
		return
	}
	
	// Register routes using veb's routing
	// Note: In real veb, you use method names or veb.route()
	
	println('Shop server starting on http://localhost:8080')
	println('')
	println('Public endpoints:')
	println('  POST /api/auth/login    - Login')
	println('  GET  /api/products      - List products')
	println('  GET  /api/products/:id  - Get product')
	println('')
	println('Protected endpoints (require Bearer token):')
	println('  POST /api/products      - Create product (admin)')
	println('  GET  /api/cart          - Get cart')
	println('  POST /api/cart/items    - Add to cart')
	
	// veb.run[ShopApp](mut app, 8080)
}
