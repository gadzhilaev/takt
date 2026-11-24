#!/usr/bin/env bash
# Switch shared-VPS edge traffic to an already healthy blue/green slot.
# Run on the VPS after installing the matching Nginx config and upstream include.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="$ROOT/deploy/docker-compose.bluegreen.yml"
ENV_FILE="$ROOT/.env"
NGINX_CONTAINER="${TAKT_NGINX_CONTAINER:-gadzhilaev-nginx-1}"
NGINX_DIR="${TAKT_NGINX_DIR:-/etc/takt/nginx}"
ACTIVE_FILE="$NGINX_DIR/active-slot"
UPSTREAM_FILE="$NGINX_DIR/active-upstreams.conf"
LOCK_FILE="$NGINX_DIR/slot-switch.lock"

usage() {
  echo "Usage: $0 blue|green|legacy [--build]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
SLOT="$1"
BUILD=0
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--build" ]] || usage
  BUILD=1
fi
[[ "$SLOT" == "blue" || "$SLOT" == "green" || "$SLOT" == "legacy" ]] || usage
[[ "$SLOT" != "legacy" || "$BUILD" -eq 0 ]] || usage
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 1; }
[[ -f "$UPSTREAM_FILE" ]] || {
  echo "Missing $UPSTREAM_FILE; install the Nginx slot config first (see deploy/DEPLOY.md)." >&2
  exit 1
}

exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another slot switch is running." >&2; exit 1; }

if [[ "$SLOT" == "legacy" ]]; then
  BACKEND=takt-backend
  FRONTEND=takt-frontend
else
  BACKEND="takt-backend-$SLOT"
  FRONTEND="takt-frontend-$SLOT"
  # Apply the compatible schema change once while only the incumbent serves traffic.
  # The candidate has AUTO_MIGRATE=false so it cannot race the active version.
  if [[ "$BUILD" -eq 1 ]]; then
    docker compose -f "$ROOT/deploy/docker-compose.prod.yml" --env-file "$ENV_FILE" build --pull=false backend
  fi
  docker compose -f "$ROOT/deploy/docker-compose.prod.yml" --env-file "$ENV_FILE" run --rm --no-deps backend alembic upgrade head
  if [[ "$BUILD" -eq 1 ]]; then
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build --pull=false "backend-$SLOT" "frontend-$SLOT"
  fi
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d "backend-$SLOT" "frontend-$SLOT"
fi

wait_healthy() {
  local container="$1" deadline=$((SECONDS + 240)) state
  while (( SECONDS < deadline )); do
    state="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)"
    [[ "$state" == "healthy" ]] && return 0
    [[ "$state" == "unhealthy" || "$state" == "exited" ]] && break
    sleep 3
  done
  echo "$container did not become healthy (state: ${state:-missing})." >&2
  return 1
}

wait_healthy "$BACKEND"
wait_healthy "$FRONTEND"

old_slot="$(cat "$ACTIVE_FILE" 2>/dev/null || echo legacy)"
case "$old_slot" in
  blue) old_backend=takt-backend-blue; old_frontend=takt-frontend-blue ;;
  green) old_backend=takt-backend-green; old_frontend=takt-frontend-green ;;
  legacy) old_backend=takt-backend; old_frontend=takt-frontend ;;
  *) echo "Unknown active slot '$old_slot' in $ACTIVE_FILE" >&2; exit 1 ;;
esac

write_upstreams() {
  local backend="$1" frontend="$2" tmp
  tmp="$(mktemp "$NGINX_DIR/active-upstreams.conf.XXXXXX")"
  cat >"$tmp" <<EOF
upstream takt_api { server $backend:8000; }
upstream takt_web { server $frontend:3000; }
EOF
  chmod 644 "$tmp"
  mv -f "$tmp" "$UPSTREAM_FILE"
}

restore_old_slot() {
  echo "Restoring traffic to $old_slot after failed post-switch check." >&2
  write_upstreams "$old_backend" "$old_frontend"
  printf '%s\n' "$old_slot" >"$ACTIVE_FILE"
  docker exec "$NGINX_CONTAINER" nginx -t
  docker exec "$NGINX_CONTAINER" nginx -s reload
}

write_upstreams "$BACKEND" "$FRONTEND"
printf '%s\n' "$SLOT" >"$ACTIVE_FILE"
if ! docker exec "$NGINX_CONTAINER" nginx -t; then
  restore_old_slot
  exit 1
fi
docker exec "$NGINX_CONTAINER" nginx -s reload

if ! curl --fail --silent --show-error --max-time 20 https://taktapp.ru/login >/dev/null; then
  restore_old_slot
  exit 1
fi

if [[ "$SLOT" != "legacy" ]]; then
  echo "Legacy backend remains the singleton worker for due reminders, check-ins, and digests."
fi

echo "Traffic now uses $SLOT. Previous slot ($old_slot) remains available for rollback."
echo "To revert: $0 $old_slot"
