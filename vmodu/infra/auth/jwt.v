// jwt.v - JWT Authentication for VModulith
// Reuses: crypto.hmac, crypto.sha256, encoding.base64, json from V standard library

module auth

import crypto.hmac
import crypto.sha256
import encoding.base64
import json2
import time
import rand

// JWT Token structure
pub struct JWTToken {
pub:
	header    JWTHeader
	payload   JWTPayload
	signature string
}

// JWT Header
pub struct JWTHeader {
pub:
	alg string = 'HS256'
	typ string = 'JWT'
}

// JWT Payload
pub struct JWTPayload {
pub mut:
	iss string     // Issuer
	sub string     // Subject (user ID)
	aud string     // Audience
	exp i64        // Expiration time
	iat i64        // Issued at
	nbf i64        // Not before
	jti string     // JWT ID
	
	// Custom claims
	roles []string
	permissions []string
	data map[string]string
}

// JWTConfig for token generation
pub struct JWTConfig {
pub:
	secret          string
	issuer          string = 'vmodu'
	audience        string
	access_ttl      int = 3600      // 1 hour
	refresh_ttl     int = 86400     // 24 hours
}

// JWTManager handles token operations
@[heap]
pub struct JWTManager {
pub:
	config JWTConfig
}

// new_jwt_manager creates a new JWT manager
pub fn new_jwt_manager(config JWTConfig) JWTManager {
	return JWTManager{config: config}
}

// generate creates a new JWT token
pub fn (j &JWTManager) generate(user_id string, roles []string, permissions []string) !string {
	now := time.now().unix()
	
	header := JWTHeader{}
	payload := JWTPayload{
		iss: j.config.issuer
		sub: user_id
		aud: j.config.audience
		iat: now
		nbf: now
		exp: now + j.config.access_ttl
		jti: generate_jti()
		roles: roles
		permissions: permissions
		data: {}
	}
	
	// Encode header and payload
	header_json := json2.encode(header, escape_unicode: true, time_as_unix: true)
	payload_json := json2.encode(payload, escape_unicode: true, time_as_unix: true)
	
	header_b64 := base64.url_encode(header_json.bytes())
	payload_b64 := base64.url_encode(payload_json.bytes())
	
	// Create signature
	signing_input := '${header_b64}.${payload_b64}'
	signature := hmac.new(j.config.secret.bytes(), signing_input.bytes(), sha256.sum, sha256.block_size)
	signature_b64 := base64.url_encode(signature)
	
	return '${header_b64}.${payload_b64}.${signature_b64}'
}

// verify validates a JWT token
pub fn (j &JWTManager) verify(token string) !JWTPayload {
	parts := token.split('.')
	if parts.len != 3 {
		return error('invalid token format')
	}
	
	header_b64 := parts[0]
	payload_b64 := parts[1]
	signature_b64 := parts[2]
	
	// Verify signature
	signing_input := '${header_b64}.${payload_b64}'
	expected_sig := hmac.new(j.config.secret.bytes(), signing_input.bytes(), sha256.sum, sha256.block_size)
	expected_sig_b64 := base64.url_encode(expected_sig)
	
	if signature_b64 != expected_sig_b64 {
		return error('invalid signature')
	}
	
	// Decode payload
	payload_json := base64.url_decode(payload_b64)
	payload := json2.decode[JWTPayload](payload_json.bytestr())!
	
	// Check expiration
	now := time.now().unix()
	if payload.exp > 0 && payload.exp < now {
		return error('token expired')
	}
	
	// Check not before
	if payload.nbf > now {
		return error('token not yet valid')
	}
	
	return payload
}

// refresh creates a new token from a valid one
pub fn (j &JWTManager) refresh(token string) !string {
	payload := j.verify(token)!
	return j.generate(payload.sub, payload.roles, payload.permissions)!
}

// generate_jti generates a unique JWT ID
fn generate_jti() string {
	return '${time.now().unix()}_${rand.intn(1000000) or { 0 }}'
}

// Permission checker
pub struct PermissionChecker {
pub:
	payload JWTPayload
}

// has_role checks if user has a role
pub fn (p &PermissionChecker) has_role(role string) bool {
	return role in p.payload.roles
}

// has_permission checks if user has a permission
pub fn (p &PermissionChecker) has_permission(permission string) bool {
	return permission in p.payload.permissions
}

// has_any_role checks if user has any of the roles
pub fn (p &PermissionChecker) has_any_role(roles []string) bool {
	for role in roles {
		if p.has_role(role) {
			return true
		}
	}
	return false
}

// has_all_permissions checks if user has all permissions
pub fn (p &PermissionChecker) has_all_permissions(permissions []string) bool {
	for permission in permissions {
		if !p.has_permission(permission) {
			return false
		}
	}
	return true
}

// RBAC (Role-Based Access Control)

// Role definition
pub struct Role {
pub:
	name        string
	permissions []string
}

// RBACManager manages roles and permissions
@[heap]
pub struct RBACManager {
pub mut:
	roles map[string]Role
}

// new_rbac_manager creates a new RBAC manager
pub fn new_rbac_manager() RBACManager {
	return RBACManager{
		roles: {}
	}
}

// add_role adds a role
pub fn (mut r RBACManager) add_role(role Role) {
	r.roles[role.name] = role
}

// get_role gets a role by name
pub fn (r &RBACManager) get_role(name string) ?Role {
	return r.roles[name] or { return none }
}

// get_permissions gets all permissions for a role
pub fn (r &RBACManager) get_permissions(role_name string) []string {
	if role := r.roles[role_name] {
		return role.permissions
	}
	return []
}

// check checks if user has permission through any role
pub fn (r &RBACManager) check(user_roles []string, permission string) bool {
	for role_name in user_roles {
		perms := r.get_permissions(role_name)
		if permission in perms {
			return true
		}
	}
	return false
}

// Predefined roles for e-commerce
pub fn setup_ecommerce_roles() RBACManager {
	mut rbac := new_rbac_manager()
	
	// Customer role
	rbac.add_role(Role{
		name: 'customer'
		permissions: [
			'product:view',
			'product:search',
			'cart:view',
			'cart:modify',
			'order:create',
			'order:view_own',
			'order:cancel_own',
			'profile:view',
			'profile:edit',
		]
	})
	
	// Merchant role
	rbac.add_role(Role{
		name: 'merchant'
		permissions: [
			'product:view',
			'product:create',
			'product:edit_own',
			'product:delete_own',
			'order:view_own',
			'order:process',
			'inventory:manage',
			'shop:manage',
		]
	})
	
	// Admin role
	rbac.add_role(Role{
		name: 'admin'
		permissions: [
			'product:view',
			'product:create',
			'product:edit',
			'product:delete',
			'order:view_all',
			'order:process',
			'order:cancel',
			'user:view',
			'user:edit',
			'user:delete',
			'shop:view_all',
			'shop:manage',
			'system:configure',
		]
	})
	
	return rbac
}

// Session management
pub struct Session {
pub:
	id         string
	user_id    string
	created_at i64
	expires_at i64
	ip_address string
	user_agent string
}

// SessionManager manages user sessions
@[heap]
pub struct SessionManager {
pub mut:
	sessions map[string]Session
	ttl      int = 86400  // 24 hours
}

// new_session_manager creates a session manager
pub fn new_session_manager() SessionManager {
	return SessionManager{
		sessions: {}
	}
}

// create creates a new session
pub fn (mut s SessionManager) create(user_id string, ip string, user_agent string) Session {
	session := Session{
		id:         '${time.now().unix()}_${rand.intn(1000000) or { 0 }}'
		user_id:    user_id
		created_at: time.now().unix()
		expires_at: time.now().unix() + s.ttl
		ip_address: ip
		user_agent: user_agent
	}
	s.sessions[session.id] = session
	return session
}

// get gets a session by ID
pub fn (s &SessionManager) get(session_id string) ?Session {
	session := s.sessions[session_id] or { return none }
	
	// Check expiration
	if session.expires_at < time.now().unix() {
		return none
	}
	
	return session
}

// delete deletes a session
pub fn (mut s SessionManager) delete(session_id string) {
	s.sessions.delete(session_id)
}

// cleanup removes expired sessions
pub fn (mut s SessionManager) cleanup() {
	now := time.now().unix()
	mut expired := []string{}
	
	for id, session in s.sessions {
		if session.expires_at < now {
			expired << id
		}
	}
	
	for id in expired {
		s.sessions.delete(id)
	}
}

// Middleware helper for HTTP authentication
pub struct AuthMiddleware {
pub:
	jwt_manager     &JWTManager
	rbac_manager    &RBACManager
	required_roles  []string
	required_perms  []string
}

// new_auth_middleware creates auth middleware
pub fn new_auth_middleware(jwt &JWTManager, rbac &RBACManager) AuthMiddleware {
	return AuthMiddleware{
		jwt_manager:  jwt
		rbac_manager: rbac
		required_roles: []
		required_perms: []
	}
}

// require_role adds required role
pub fn (a &AuthMiddleware) require_role(role string) AuthMiddleware {
	mut roles := a.required_roles.clone()
	roles << role
	return AuthMiddleware{
		jwt_manager:    a.jwt_manager
		rbac_manager:   a.rbac_manager
		required_roles: roles
		required_perms: a.required_perms
	}
}

// require_permission adds required permission
pub fn (a &AuthMiddleware) require_permission(perm string) AuthMiddleware {
	mut perms := a.required_perms.clone()
	perms << perm
	return AuthMiddleware{
		jwt_manager:    a.jwt_manager
		rbac_manager:   a.rbac_manager
		required_roles: a.required_roles
		required_perms: perms
	}
}

// extract_token extracts token from Authorization header
pub fn extract_token(auth_header string) !string {
	if !auth_header.starts_with('Bearer ') {
		return error('invalid authorization header format')
	}
	return auth_header[7..]
}
