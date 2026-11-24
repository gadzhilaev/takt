#!/usr/bin/env bash
# Operator wrapper for the shared VPS blue-green procedure.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE="$ROOT/deploy/docker-compose.bluegreen.yml"
ENV_FILE="$ROOT/.env"
ACTIVE_FILE="${TAKT_BLUE_GREEN_ACTIVE_FILE:-/etc/takt/nginx/active-slot}"

compose() { docker compose -f "$COMPOSE" --env-file "$ENV_FILE" "$@"; }
usage() {
  cat <<'HELP'
Usage:
  blue-green.sh status
  blue-green.sh prepare blue|green [--build]
  blue-green.sh switch blue|green|legacy
  blue-green.sh rollback
  blue-green.sh stop blue|green

`prepare` starts the inactive API-only slot, then waits for health checks.
`switch` safely changes nginx upstreams, validates/reloads nginx, probes the
public site and retains the previous slot for rollback. No production action is
automatic; these commands must be run explicitly on the VPS.
HELP
}
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 1; }
active_slot() { [[ -f "$ACTIVE_FILE" ]] && tr -d '[:space:]' < "$ACTIVE_FILE" || echo legacy; }
case "${1:-}" in
  status)
    echo "active=$(active_slot)"
    compose ps
    ;;
  prepare)
    slot="${2:-}"
    [[ "$slot" == blue || "$slot" == green ]] || { usage; exit 2; }
    [[ "$slot" != "$(active_slot)" ]] || { echo "Refusing to prepare active slot" >&2; exit 2; }
    shift 2
    extra=()
    [[ "${1:-}" == --build ]] && extra+=(--build)
    exec "$ROOT/deploy/scripts/server-switch-slot.sh" "$slot" "${extra[@]}"
    ;;
  switch)
    slot="${2:-}"
    [[ "$slot" == blue || "$slot" == green || "$slot" == legacy ]] || { usage; exit 2; }
    exec "$ROOT/deploy/scripts/server-switch-slot.sh" "$slot"
    ;;
  rollback)
    current="$(active_slot)"
    case "$current" in blue) target=green ;; green) target=blue ;; *) echo "No blue/green slot to roll back from" >&2; exit 2 ;; esac
    exec "$ROOT/deploy/scripts/server-switch-slot.sh" "$target"
    ;;
  stop)
    slot="${2:-}"
    [[ "$slot" == blue || "$slot" == green ]] || { usage; exit 2; }
    [[ "$slot" != "$(active_slot)" ]] || { echo "Refusing to stop active slot" >&2; exit 2; }
    compose stop "backend-$slot" "frontend-$slot"
    ;;
  *) usage; exit 2 ;;
esac
