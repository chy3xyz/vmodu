#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# VModu Runtime Deployment Script
# Usage: ./deploy.sh [dev|prod|full] [up|down|restart|logs]
# ═══════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$DEPLOY_DIR")"

# Default values
ENVIRONMENT="${1:-dev}"
ACTION="${2:-up}"

# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ═══════════════════════════════════════════════════════════════
# Environment Validation
# ═══════════════════════════════════════════════════════════════
validate_environment() {
    case $ENVIRONMENT in
        dev|prod|full)
            log_info "Environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT"
            log_info "Usage: $0 [dev|prod|full] [up|down|restart|logs|build]"
            exit 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# File Selection
# ═══════════════════════════════════════════════════════════════
get_compose_file() {
    case $ENVIRONMENT in
        dev)
            echo "$DEPLOY_DIR/docker-compose.yml"
            ;;
        prod)
            echo "$DEPLOY_DIR/docker-compose.prod.yml"
            ;;
        full)
            echo "$DEPLOY_DIR/docker-compose.full.yml"
            ;;
    esac
}

get_env_file() {
    case $ENVIRONMENT in
        dev)
            echo "$DEPLOY_DIR/.env"
            ;;
        prod|full)
            echo "$DEPLOY_DIR/.env.production"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# Environment Setup
# ═══════════════════════════════════════════════════════════════
setup_environment() {
    log_info "Setting up environment..."

    local env_file=$(get_env_file)
    local env_example="$DEPLOY_DIR/.env.example"

    if [[ ! -f "$env_file" ]]; then
        if [[ -f "$env_example" ]]; then
            log_warn "Environment file not found: $env_file"
            log_info "Creating from example..."
            cp "$env_example" "$env_file"
            log_warn "Please edit $env_file with your secrets before continuing!"

            if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "full" ]]; then
                read -p "Continue anyway? (y/N) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        else
            log_error "Example environment file not found: $env_example"
            exit 1
        fi
    fi

    # Check SSL certificates for production
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        local ssl_dir="$DEPLOY_DIR/config/nginx/ssl"
        if [[ ! -f "$ssl_dir/cert.pem" || ! -f "$ssl_dir/key.pem" ]]; then
            log_warn "SSL certificates not found in $ssl_dir"
            log_info "Generating self-signed certificates..."
            mkdir -p "$ssl_dir"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "$ssl_dir/key.pem" \
                -out "$ssl_dir/cert.pem" \
                -subj "/C=US/ST=State/L=City/O=VModu/CN=localhost"
            log_warn "Using self-signed certificates. Replace with proper certificates for production!"
        fi
    fi

    log_success "Environment setup complete"
}

# ═══════════════════════════════════════════════════════════════
# Docker Compose Actions
# ═══════════════════════════════════════════════════════════════
docker_up() {
    local compose_file=$(get_compose_file)
    local env_file=$(get_env_file)

    log_info "Starting VModu Runtime ($ENVIRONMENT)..."

    if [[ -f "$env_file" ]]; then
        docker-compose -f "$compose_file" --env-file "$env_file" up -d --build
    else
        docker-compose -f "$compose_file" up -d --build
    fi

    log_success "Services started!"

    # Show status
    sleep 2
    docker-compose -f "$compose_file" ps
}

docker_down() {
    local compose_file=$(get_compose_file)

    log_info "Stopping VModu Runtime ($ENVIRONMENT)..."
    docker-compose -f "$compose_file" down

    # Optionally remove volumes
    read -p "Remove volumes? This will DELETE all data! (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f "$compose_file" down -v
        log_warn "Volumes removed!"
    fi

    log_success "Services stopped"
}

docker_restart() {
    docker_down
    sleep 2
    docker_up
}

docker_logs() {
    local compose_file=$(get_compose_file)
    local service="${3:-}"

    if [[ -n "$service" ]]; then
        docker-compose -f "$compose_file" logs -f "$service"
    else
        docker-compose -f "$compose_file" logs -f
    fi
}

docker_build() {
    local compose_file=$(get_compose_file)

    log_info "Building images..."
    docker-compose -f "$compose_file" build --no-cache
    log_success "Build complete"
}

# ═══════════════════════════════════════════════════════════════
# Health Check
# ═══════════════════════════════════════════════════════════════
check_health() {
    local compose_file=$(get_compose_file)

    log_info "Checking service health..."

    # Check if containers are running
    local running=$(docker-compose -f "$compose_file" ps -q | wc -l)
    log_info "Running containers: $running"

    # Check API health endpoint
    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            log_success "API is healthy!"
            return 0
        fi

        log_info "Waiting for API... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done

    log_error "API health check failed after $max_attempts attempts"
    return 1
}

# ═══════════════════════════════════════════════════════════════
# Status Display
# ═══════════════════════════════════════════════════════════════
show_status() {
    local compose_file=$(get_compose_file)

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║             VModu Runtime - Service Status                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    docker-compose -f "$compose_file" ps

    echo ""
    echo "Endpoints:"
    echo "  API:        http://localhost:8080"

    if [[ "$ENVIRONMENT" == "dev" ]]; then
        echo "  Grafana:    http://localhost:3000 (admin/admin)"
        echo "  Prometheus: http://localhost:9091"
        echo "  PostgreSQL: localhost:5432"
        echo "  Redis:      localhost:6379"
    elif [[ "$ENVIRONMENT" == "full" ]]; then
        echo "  Grafana:    http://localhost:3000"
        echo "  Prometheus: http://localhost:9090"
        echo "  Jaeger:     http://localhost:16686"
        echo "  ClickHouse: http://localhost:8123"
    fi

    echo ""
}

# ═══════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════
cleanup() {
    log_info "Cleaning up unused Docker resources..."
    docker system prune -f
    docker volume prune -f
    log_success "Cleanup complete"
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║         VModu Runtime Deployment Script                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    validate_environment
    setup_environment

    case $ACTION in
        up|start)
            docker_up
            check_health
            show_status
            ;;
        down|stop)
            docker_down
            ;;
        restart)
            docker_restart
            check_health
            show_status
            ;;
        logs)
            docker_logs "$@"
            ;;
        build)
            docker_build
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup
            ;;
        *)
            log_error "Unknown action: $ACTION"
            log_info "Usage: $0 [dev|prod|full] [up|down|restart|logs|build|status|cleanup]"
            exit 1
            ;;
    esac
}

main "$@"
