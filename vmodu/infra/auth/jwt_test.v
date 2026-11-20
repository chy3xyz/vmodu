// jwt_test.v - Unit tests for JWT auth (no network)

module auth

import time

fn test_jwt_generate_verify_roundtrip() {
	mgr := new_jwt_manager(JWTConfig{
		secret:     'test-secret-key'
		issuer:     'vmodu-test'
		audience:   'api'
		access_ttl: 3600
	})

	token := mgr.generate('user-42', ['customer'], ['product:view']) or {
		assert false, 'generate failed: ${err}'
		return
	}

	parts := token.split('.')
	assert parts.len == 3

	payload := mgr.verify(token) or {
		assert false, 'verify failed: ${err}'
		return
	}

	assert payload.sub == 'user-42'
	assert payload.iss == 'vmodu-test'
	assert payload.aud == 'api'
	assert payload.roles == ['customer']
	assert payload.permissions == ['product:view']
	assert payload.exp > payload.iat
	assert payload.jti.len > 0
}

fn test_jwt_reject_bad_signature() {
	mgr := new_jwt_manager(JWTConfig{
		secret:     'correct-secret'
		access_ttl: 3600
	})

	token := mgr.generate('u1', [], []) or {
		assert false, 'generate failed: ${err}'
		return
	}

	parts := token.split('.')
	assert parts.len == 3
	tampered := '${parts[0]}.${parts[1]}.AAAA_bad_signature'

	mgr.verify(tampered) or {
		assert err.msg().contains('invalid signature')
		return
	}
	assert false, 'expected invalid signature'
}

fn test_jwt_reject_wrong_secret() {
	mgr_a := new_jwt_manager(JWTConfig{
		secret:     'secret-a'
		access_ttl: 3600
	})
	mgr_b := new_jwt_manager(JWTConfig{
		secret:     'secret-b'
		access_ttl: 3600
	})

	token := mgr_a.generate('u1', [], []) or {
		assert false, 'generate failed: ${err}'
		return
	}

	mgr_b.verify(token) or {
		assert err.msg().contains('invalid signature')
		return
	}
	assert false, 'expected invalid signature with wrong secret'
}

fn test_jwt_reject_expired() {
	mgr := new_jwt_manager(JWTConfig{
		secret:     'test-secret'
		access_ttl: -10 // exp = now - 10 → already expired
	})

	token := mgr.generate('u1', [], []) or {
		assert false, 'generate failed: ${err}'
		return
	}

	mgr.verify(token) or {
		assert err.msg().contains('token expired')
		return
	}
	assert false, 'expected token expired'
}

fn test_jwt_reject_invalid_format() {
	mgr := new_jwt_manager(JWTConfig{
		secret: 'test-secret'
	})

	mgr.verify('not-a-jwt') or {
		assert err.msg().contains('invalid token format')
		return
	}
	assert false, 'expected invalid token format'
}

fn test_jwt_refresh() {
	mgr := new_jwt_manager(JWTConfig{
		secret:     'test-secret'
		access_ttl: 3600
	})

	token := mgr.generate('u99', ['admin'], ['system:configure']) or {
		assert false, 'generate failed: ${err}'
		return
	}

	// Ensure iat can differ on refresh
	time.sleep(10 * time.millisecond)

	refreshed := mgr.refresh(token) or {
		assert false, 'refresh failed: ${err}'
		return
	}

	payload := mgr.verify(refreshed) or {
		assert false, 'verify refreshed failed: ${err}'
		return
	}
	assert payload.sub == 'u99'
	assert payload.roles == ['admin']
	assert payload.permissions == ['system:configure']
}

fn test_extract_token() {
	tok := extract_token('Bearer abc.def.ghi') or {
		assert false, 'extract failed: ${err}'
		return
	}
	assert tok == 'abc.def.ghi'

	extract_token('Basic xxx') or {
		assert err.msg().contains('invalid authorization')
		return
	}
	assert false, 'expected invalid authorization header format'
}

fn test_permission_checker() {
	payload := JWTPayload{
		roles:       ['customer', 'merchant']
		permissions: ['product:view', 'cart:modify']
	}
	checker := PermissionChecker{
		payload: payload
	}

	assert checker.has_role('customer')
	assert !checker.has_role('admin')
	assert checker.has_permission('product:view')
	assert !checker.has_permission('system:configure')
	assert checker.has_any_role(['admin', 'merchant'])
	assert !checker.has_any_role(['admin'])
	assert checker.has_all_permissions(['product:view', 'cart:modify'])
	assert !checker.has_all_permissions(['product:view', 'order:cancel'])
}

fn test_rbac_manager() {
	mut rbac := setup_ecommerce_roles()

	assert rbac.check(['customer'], 'product:view')
	assert !rbac.check(['customer'], 'system:configure')
	assert rbac.check(['admin'], 'system:configure')
	assert rbac.check(['merchant'], 'inventory:manage')

	role := rbac.get_role('customer') or {
		assert false, 'customer role missing'
		return
	}
	assert role.name == 'customer'
	assert 'cart:view' in role.permissions
}

fn test_session_manager() {
	mut sessions := new_session_manager()
	session := sessions.create('user-1', '127.0.0.1', 'test-agent')

	got := sessions.get(session.id) or {
		assert false, 'session should exist'
		return
	}
	assert got.user_id == 'user-1'
	assert got.ip_address == '127.0.0.1'

	sessions.delete(session.id)
	_ := sessions.get(session.id) or { return }
	assert false, 'session should be deleted'
}
