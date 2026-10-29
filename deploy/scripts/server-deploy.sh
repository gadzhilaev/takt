#!/usr/bin/env bash
# Обновление production на VPS через git pull + docker compose build.
# Использование на сервере:
#   /opt/takt/deploy/scripts/server-deploy.sh
#   /opt/takt/deploy/scripts/server-deploy.sh --no-pull
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="$ROOT/deploy/docker-compose.prod.yml"
ENV_FILE="$ROOT/.env"
SSH_KEY="${TAKT_DEPLOY_SSH_KEY:-$HOME/.ssh/takt_deploy}"

cd "$ROOT"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Нет $ENV_FILE — скопируйте из .env.example и заполните секреты." >&2
  exit 1
fi

DO_PULL=1
for arg in "$@"; do
  case "$arg" in
    --no-pull) DO_PULL=0 ;;
  esac
done

if [[ "$DO_PULL" -eq 1 ]]; then
  if [[ ! -d "$ROOT/.git" ]]; then
    echo "Каталог $ROOT не git-репозиторий. Сначала сделайте git clone." >&2
    exit 1
  fi
  export GIT_SSH_COMMAND="ssh -i ${SSH_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
  echo "==> git fetch/pull origin main"
  git fetch origin main
  git checkout main
  git pull --ff-only origin main
  git rev-parse --short HEAD
fi

echo "==> docker compose build (backend, frontend)"
# --pull=false: не упираться в Docker Hub rate limit, если base-образы уже локально
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build --pull=false backend frontend

echo "==> docker compose up -d"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

echo "==> status"
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
echo "OK: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo no-git)"
