#!/bin/bash
# Run all VModulith Runtime unit tests
# Usage: ./run_tests.sh [module_name]

set -e

cd /Users/n0x/ws_clawworld/vmodu_runtime

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           VModulith Runtime - Unit Test Suite                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

V_FLAGS="-enable-globals"

# Function to run tests for a module
run_module_tests() {
    local module_path=$1
    local module_name=$2
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing: ${module_name}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if v ${V_FLAGS} test "${module_path}"; then
        echo "✅ ${module_name} tests passed"
        return 0
    else
        echo "❌ ${module_name} tests failed"
        return 1
    fi
}

# If specific module requested
if [ $# -eq 1 ]; then
    case $1 in
        "eventbus"|"bus")
            run_module_tests "vmodu_modules/event/bus" "EventBus"
            ;;
        "eventstore"|"db")
            run_module_tests "vmodu_modules/infra/db" "Event Store"
            ;;
        "health")
            run_module_tests "vmodu_modules/infra/health" "Health Check"
            ;;
        "metrics")
            run_module_tests "vmodu_modules/infra/metrics" "Metrics"
            ;;
        "circuit")
            run_module_tests "vmodu_modules/infra/circuit" "Circuit Breaker"
            ;;
        "pool")
            run_module_tests "vmodu_modules/infra/pool" "Connection Pool"
            ;;
        "config")
            run_module_tests "vmodu_modules/config" "Configuration"
            ;;
        *)
            echo "Unknown module: $1"
            echo "Available modules: eventbus, eventstore, health, metrics, circuit, pool, config"
            exit 1
            ;;
    esac
    exit 0
fi

# Run all tests
echo "Running all module tests..."
echo ""

TOTAL=0
PASSED=0
FAILED=0

# EventBus
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/event/bus" "EventBus"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Event Store
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/infra/db" "Event Store"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Health Check
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/infra/health" "Health Check"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Metrics
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/infra/metrics" "Metrics"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Circuit Breaker
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/infra/circuit" "Circuit Breaker"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Connection Pool
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/infra/pool" "Connection Pool"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Config
TOTAL=$((TOTAL + 1))
if run_module_tests "vmodu_modules/config" "Configuration"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      Test Summary                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Total:  ${TOTAL}"
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
echo ""

if [ ${FAILED} -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi
