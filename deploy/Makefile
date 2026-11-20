# ═══════════════════════════════════════════════════════════════
# VModu Runtime - Docker Deployment Makefile
# ═══════════════════════════════════════════════════════════════

.PHONY: help dev prod full down logs status clean build

# Default target
.DEFAULT_GOAL := help

# Colors
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)VModu Runtime - Docker Deployment$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@echo "  make $(YELLOW)<target>$(NC)"
	@echo ""
	@echo "$(GREEN)Targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ═══════════════════════════════════════════════════════════════
# Development Environment
# ═══════════════════════════════════════════════════════════════
dev: ## Start development environment
	@echo "$(BLUE)Starting development environment...$(NC)"
	@./scripts/deploy.sh dev up

dev-down: ## Stop development environment
	@echo "$(YELLOW)Stopping development environment...$(NC)"
	@./scripts/deploy.sh dev down

dev-logs: ## View development logs
	@./scripts/deploy.sh dev logs

dev-restart: ## Restart development environment
	@./scripts/deploy.sh dev restart

# ═══════════════════════════════════════════════════════════════
# Production Environment
# ═══════════════════════════════════════════════════════════════
prod: ## Start production environment
	@echo "$(BLUE)Starting production environment...$(NC)"
	@./scripts/deploy.sh prod up

prod-down: ## Stop production environment
	@echo "$(YELLOW)Stopping production environment...$(NC)"
	@./scripts/deploy.sh prod down

prod-logs: ## View production logs
	@./scripts/deploy.sh prod logs

prod-restart: ## Restart production environment
	@./scripts/deploy.sh prod restart

# ═══════════════════════════════════════════════════════════════
# Full/Enterprise Environment
# ═══════════════════════════════════════════════════════════════
full: ## Start full enterprise environment
	@echo "$(BLUE)Starting enterprise environment...$(NC)"
	@./scripts/deploy.sh full up

full-down: ## Stop full environment
	@echo "$(YELLOW)Stopping enterprise environment...$(NC)"
	@./scripts/deploy.sh full down

full-logs: ## View full environment logs
	@./scripts/deploy.sh full logs

# ═══════════════════════════════════════════════════════════════
# Build & Maintenance
# ═══════════════════════════════════════════════════════════════
build: ## Build all Docker images
	@echo "$(BLUE)Building Docker images...$(NC)"
	@./scripts/deploy.sh dev build

status: ## Show service status
	@./scripts/deploy.sh dev status

clean: ## Clean up unused Docker resources
	@echo "$(YELLOW)Cleaning up...$(NC)"
	@./scripts/deploy.sh dev cleanup
	@docker system prune -f

# ═══════════════════════════════════════════════════════════════
# Database Operations
# ═══════════════════════════════════════════════════════════════
db-backup: ## Backup PostgreSQL database
	@echo "$(BLUE)Backing up database...$(NC)"
	@mkdir -p backups
	@docker exec vmodu-postgres pg_dump -U vmodu vmodu > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Backup complete!$(NC)"

db-shell: ## Open PostgreSQL shell
	@docker exec -it vmodu-postgres psql -U vmodu -d vmodu

db-migrate: ## Run database migrations
	@echo "$(BLUE)Running migrations...$(NC)"
	@docker exec -i vmodu-postgres psql -U vmodu -d vmodu < scripts/init-db.sql

# ═══════════════════════════════════════════════════════════════
# Monitoring
# ═══════════════════════════════════════════════════════════════
logs-api: ## View API logs only
	@docker logs -f vmodu-api

logs-db: ## View database logs only
	@docker logs -f vmodu-postgres

logs-redis: ## View Redis logs only
	@docker logs -f vmodu-redis

top: ## Show resource usage
	@docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# ═══════════════════════════════════════════════════════════════
# Health Checks
# ═══════════════════════════════════════════════════════════════
health: ## Check service health
	@echo "$(BLUE)Checking service health...$(NC)"
	@curl -s http://localhost:8080/health || echo "$(RED)API is not healthy$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}"

test: ## Run integration tests
	@echo "$(BLUE)Running tests...$(NC)"
	@cd .. && v -enable-globals run test_integration.v

# ═══════════════════════════════════════════════════════════════
# SSL/TLS Setup
# ═══════════════════════════════════════════════════════════════
ssl-generate: ## Generate self-signed SSL certificates
	@echo "$(BLUE)Generating SSL certificates...$(NC)"
	@mkdir -p config/nginx/ssl
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout config/nginx/ssl/key.pem \
		-out config/nginx/ssl/cert.pem \
		-subj "/C=US/ST=State/L=City/O=VModu/CN=localhost"
	@echo "$(GREEN)SSL certificates generated!$(NC)"

ssl-real: ## Setup real SSL certificates (provide paths)
	@echo "$(YELLOW)Copy your certificates to config/nginx/ssl/$(NC)"
	@echo "  - cert.pem (certificate)"
	@echo "  - key.pem (private key)"
