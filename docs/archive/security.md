# Security Best Practices

Security guidelines for deploying and operating VModulith Runtime.

## Overview

VModulith Runtime implements defense in depth with multiple security layers:

1. **Network Security** - TLS, firewalls, rate limiting
2. **Authentication** - Token-based API access
3. **Authorization** - Role-based access control
4. **Isolation** - WASM sandbox, process boundaries
5. **Audit** - Logging, monitoring, alerting

## Network Security

### TLS Configuration

Enable TLS for all external-facing services:

```json
{
  "gateway": {
    "tls_cert": "/etc/vmodu/certs/server.crt",
    "tls_key": "/etc/vmodu/certs/server.key",
    "tls_ca": "/etc/vmodu/certs/ca.crt",
    "tls_min_version": "1.3",
    "tls_cipher_suites": [
      "TLS_AES_256_GCM_SHA384",
      "TLS_CHACHA20_POLY1305_SHA256"
    ]
  }
}
```

Generate certificates:

```bash
# Self-signed (development)
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout server.key -out server.crt

# Let's Encrypt (production)
certbot certonly --standalone -d api.vmodu.io
```

### Firewall Rules

```bash
# UFW (Ubuntu)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow API
sudo ufw allow from 10.0.0.0/8 to any port 8080 proto tcp

# Allow cluster (internal only)
sudo ufw allow from 10.0.0.0/24 to any port 9000:9001 proto tcp

# Allow admin (restrict further)
sudo ufw allow from 10.0.0.10 to any port 8082 proto tcp

# Deny everything else
sudo ufw enable
```

### Rate Limiting

Prevent DoS attacks:

```json
{
  "gateway": {
    "rate_limit": 1000,
    "rate_limit_burst": 2000,
    "rate_limit_per_ip": 100
  }
}
```

## Authentication

### Admin Token

Generate strong admin token:

```bash
# Generate secure token
openssl rand -hex 32

# Or use pwgen
pwgen -s 64 1
```

Store securely:

```bash
# Use environment variable
export VMODU_ADMIN_TOKEN=$(cat /etc/vmodu/admin_token)

# Or secrets manager
aws secretsmanager get-secret-value --secret-id vmodu/admin-token
```

### API Authentication

```bash
# Include token in requests
curl -H "Authorization: Bearer ${TOKEN}" \
  http://localhost:8080/api/admin/metrics
```

### mTLS for Cluster

Enable mutual TLS between cluster nodes:

```json
{
  "cluster": {
    "mtls_enabled": true,
    "mtls_cert": "/etc/vmodu/certs/node.crt",
    "mtls_key": "/etc/vmodu/certs/node.key",
    "mtls_ca": "/etc/vmodu/certs/ca.crt"
  }
}
```

## Authorization

### Role-Based Access Control

Define roles:

```json
{
  "rbac": {
    "roles": {
      "admin": {
        "permissions": ["*"]
      },
      "operator": {
        "permissions": [
          "read:metrics",
          "read:logs",
          "write:config"
        ]
      },
      "viewer": {
        "permissions": [
          "read:metrics"
        ]
      }
    }
  }
}
```

Assign roles:

```bash
vmodu rbac assign --user alice --role operator
```

## WASM Sandbox Security

### Resource Limits

Strict limits prevent sandbox escape:

```json
{
  "wasm": {
    "memory_limit": 16777216,     // 16MB
    "cpu_time_ms": 5000,          // 5 seconds
    "fuel_limit": 10000000,       // 10M instructions
    "max_call_depth": 100,
    "syscall_whitelist": [
      "fd_read",
      "fd_write",
      "clock_get"
    ]
  }
}
```

### Module Verification

Verify WASM modules before loading:

```bash
# Check module hash
sha256sum module.wasm

# Verify signature
vmodu wasm verify --module module.wasm --pubkey key.pem

# Scan for malicious patterns
vmodu wasm scan module.wasm
```

### Network Isolation

WASM modules cannot access network by default:

```json
{
  "wasm": {
    "allow_network": false,
    "allowed_hosts": [],
    "allow_file_system": false
  }
}
```

## Data Protection

### Encryption at Rest

Encrypt event store:

```bash
# Using LUKS
sudo cryptsetup luksFormat /dev/sdb
sudo cryptsetup open /dev/sdb vmodu-data
sudo mkfs.ext4 /dev/mapper/vmodu-data
sudo mount /dev/mapper/vmodu-data /data/vmodu
```

### Encryption in Transit

Always use TLS for external communication:

```bash
# Enforce TLS
vmodu --tls-required

# HSTS header
vmodu --hsts-max-age 31536000
```

### Secrets Management

Never store secrets in config files:

```bash
# Use environment variables
export VMODU_ETH_RPC_URL="https://..."
export VMODU_LLM_API_KEY="sk-..."

# Or secrets manager
export VMODU_ADMIN_TOKEN=$(vault kv get -field=token secret/vmodu)
```

## Audit Logging

### Enable Audit Log

```json
{
  "logging": {
    "audit_enabled": true,
    "audit_file": "/var/log/vmodu/audit.log",
    "audit_events": [
      "auth.success",
      "auth.failure",
      "admin.config_change",
      "cluster.node_join",
      "cluster.node_leave",
      "wasm.module_load"
    ]
  }
}
```

### Audit Log Format

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "event": "auth.success",
  "user": "admin",
  "ip": "10.0.0.10",
  "action": "login",
  "resource": "/api/admin",
  "result": "success"
}
```

### Log Retention

```bash
# Rotate logs daily
logrotate /etc/logrotate.d/vmodu

# Archive to S3
aws s3 sync /var/log/vmodu s3://vmodu-logs/$(date +%Y/%m/)
```

## Vulnerability Management

### Keep Updated

```bash
# Check for updates
vmodu update check

# Apply security patches
vmodu update apply --security-only

# Subscribe to security advisories
# https://github.com/vmodu/runtime/security/advisories
```

### Dependency Scanning

```bash
# Scan for vulnerabilities
vmodu security scan

# Check WASM modules
vmodu wasm scan --all

# Dependency check
v audit
```

## Web3 Security

### RPC Endpoint Security

```bash
# Use private endpoints
vmodu config set adapters.evm.rpc_url "https://private-node.example.com"

# Enable authentication
vmodu config set adapters.evm.rpc_headers "Authorization: Bearer ${RPC_TOKEN}"
```

### Transaction Signing

```bash
# Use hardware wallet
vmodu wallet connect --type ledger

# Multi-sig for high-value
vmodu wallet create-multisig --threshold 2 --signers alice,bob,charlie
```

### Smart Contract Verification

```bash
# Verify contract before interaction
vmodu evm verify-contract --address 0x... --source Contract.sol

# Check for known vulnerabilities
vmodu evm scan-contract --address 0x...
```

## Incident Response

### Security Incident Checklist

1. **Isolate** affected systems
2. **Preserve** logs and evidence
3. **Assess** scope of breach
4. **Contain** the threat
5. **Eradicate** root cause
6. **Recover** services
7. **Learn** from incident

### Emergency Procedures

```bash
# Lockdown mode (disable external API)
vmodu admin lockdown

# Revoke all tokens
vmodu admin revoke-tokens --all

# Kill all WASM modules
vmodu wasm kill-all

# Rotate secrets
vmodu admin rotate-secrets
```

## Compliance

### GDPR

- Enable data encryption
- Implement retention policies
- Provide data export
- Support deletion requests

```bash
# Export user data
vmodu gdpr export --user <id>

# Delete user data
vmodu gdpr delete --user <id>
```

### SOC 2

- Audit logging enabled
- Access controls implemented
- Monitoring in place
- Incident response documented

## Security Checklist

Before production deployment:

- [ ] TLS enabled for all services
- [ ] Strong admin token generated
- [ ] Firewall rules configured
- [ ] Rate limiting enabled
- [ ] Audit logging enabled
- [ ] Resource limits set for WASM
- [ ] Secrets stored securely
- [ ] mTLS for cluster (if used)
- [ ] Monitoring configured
- [ ] Incident response plan ready
- [ ] Security updates applied
- [ ] Penetration test completed

## Reporting Security Issues

**DO NOT** create public issues for security bugs.

Instead:
- Email: security@vmodu.io
- GPG Key: [security@vmodu.io.asc](https://vmodu.io/security.asc)
- Response time: 24 hours
- Bounty program: [vmodu.io/security](https://vmodu.io/security)

Include:
- Description of vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (optional)

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
