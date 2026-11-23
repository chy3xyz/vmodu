#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# VModu — Docker Compose config smoke (no containers started)
# Usage: ./scripts/compose-smoke.sh
# Exit 0 on success or when Docker is unavailable (SKIP).
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=""
CLEANUP_ENV=0

cd "$DEPLOY_DIR"

if [[ -f .env ]]; then
  ENV_FILE=".env"
else
  if [[ ! -f .env.example ]]; then
    echo "ERROR: neither .env nor .env.example found in $DEPLOY_DIR" >&2
    exit 1
  fi
  ENV_FILE=".env.smoke"
  cp .env.example "$ENV_FILE"
  CLEANUP_ENV=1
  echo "NOTE: no .env — using temporary $ENV_FILE from .env.example (not overwriting .env)"
fi

cleanup() {
  if [[ "$CLEANUP_ENV" -eq 1 && -f "$ENV_FILE" ]]; then
    rm -f "$ENV_FILE"
  fi
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not found — compose smoke skipped (exit 0)"
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "SKIP: docker compose plugin not found — compose smoke skipped (exit 0)"
  exit 0
fi

echo "Validating compose: -f $COMPOSE_FILE --env-file $ENV_FILE"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" config >/dev/null
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" config --quiet

echo "OK: docker compose config validated"
exit 0
