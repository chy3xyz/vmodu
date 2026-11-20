#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# VModu Runtime Health Check Script
# ═══════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_URL="${API_URL:-http://localhost:8080}"
TIMEOUT=5

# Status tracking
ALL_HEALTHY=true

check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    echo -n "Checking $name... "

    if response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null); then
        if [ "$response" = "$expected_code" ]; then
            echo -e "${GREEN}✓ OK${NC}"
            return 0
        else
            echo -e "${RED}✗ HTTP $response${NC}"
            ALL_HEALTHY=false
            return 1
        fi
    else
        echo -e "${RED}✗ Connection failed${NC}"
        ALL_HEALTHY=false
        return 1
    fi
}

check_docker() {
    echo -n "Checking Docker... "
    if docker info > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
        return 0
    else
        echo -e "${RED}✗ Not running${NC}"
        ALL_HEALTHY=false
        return 1
    fi
}

check_container() {
    local name=$1

    echo -n "Checking container: $name... "

    if docker ps --format "{{.Names}}" | grep -q "^${name}$"; then
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "unknown")

        if [ "$status" = "healthy" ] || [ "$status" = "unknown" ]; then
            echo -e "${GREEN}✓ Running${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Status: $status${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Not running${NC}"
        ALL_HEALTHY=false
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           VModu Runtime Health Check                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check Docker
check_docker
echo ""

# Check containers
echo "Container Status:"
check_container "vmodu-api" || true
check_container "vmodu-postgres" || true
check_container "vmodu-redis" || true
check_container "vmodu-prometheus" || true
check_container "vmodu-grafana" || true
echo ""

# Check services
echo "Service Endpoints:"
check_service "API Health" "$API_URL/health" || true
check_service "API Docs" "$API_URL/docs" || true
check_service "Grafana" "http://localhost:3000/login" || true
check_service "Prometheus" "http://localhost:9091/-/healthy" || true
echo ""

# Summary
echo "════════════════════════════════════════════════════════════"
if [ "$ALL_HEALTHY" = true ]; then
    echo -e "${GREEN}✓ All systems operational${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some services are not healthy${NC}"
    exit 1
fi
