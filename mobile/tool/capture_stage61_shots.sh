#!/usr/bin/env bash
# Stage 6.1 — real simulator screenshots for App Store (raw captures).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${UDID:?Set UDID to iPhone 6.9\" simulator}"
API_BASE="${API_BASE:-http://127.0.0.1:8000}"
STORE_EMAIL="${STORE_EMAIL:?}"
STORE_PASSWORD="${STORE_PASSWORD:?}"
OUT_RAW="${OUT_RAW:-/tmp/takt-stage61-raw}"
LOG="/tmp/takt-stage61-flutter.log"
BUNDLE="ru.gadzhilaev.takt"

mkdir -p "$OUT_RAW"
rm -f "$OUT_RAW"/*.png "$LOG"

login_json=$(curl -sS -X POST "$API_BASE/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$STORE_EMAIL\",\"password\":\"$STORE_PASSWORD\"}")
TOKEN=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$login_json")

export API_BASE TOKEN
export PROJECT_ID="${PROJECT_ID:-}" CHECKIN_ID="${CHECKIN_ID:-}"
eval "$(API_BASE="$API_BASE" TOKEN="$TOKEN" PROJECT_ID="${PROJECT_ID:-}" CHECKIN_ID="${CHECKIN_ID:-}" python3 - <<'PY'
import json, os, urllib.request
api = os.environ["API_BASE"]
token = os.environ["TOKEN"]
req = urllib.request.Request(
    f"{api}/api/v1/rhythm/checkins/current",
    headers={"Authorization": f"Bearer {token}"},
)
with urllib.request.urlopen(req) as r:
    d = json.load(r)
c = (d.get("checkins") or [None])[0]
if not c:
    raise SystemExit("no pending checkin for review user")
pid = os.environ.get("PROJECT_ID") or c["project"]["id"]
cid = os.environ.get("CHECKIN_ID") or c["id"]
req2 = urllib.request.Request(
    f"{api}/api/v1/rhythm/checkins/{cid}",
    headers={"Authorization": f"Bearer {token}"},
)
with urllib.request.urlopen(req2) as r:
    detail = json.load(r)["checkin"]
items = detail.get("items") or []
title = (items[0].get("title") if items else "") or ""
# shell-safe
import shlex
print(f"PROJECT_ID={shlex.quote(pid)}")
print(f"CHECKIN_ID={shlex.quote(cid)}")
print(f"ACTION_TOKEN={shlex.quote(detail.get('action_token') or '')}")
print(f"TASK_ID={shlex.quote(items[0].get('task_id') if items else '')}")
print(f"TASK_TITLE={shlex.quote(title)}")
PY
)"

echo "PROJECT_ID=$PROJECT_ID CHECKIN_ID=$CHECKIN_ID"

status_bar() {
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true
}

shot() {
  local name="$1"
  status_bar
  xcrun simctl io "$UDID" screenshot "$OUT_RAW/${name}.png" >/dev/null
  echo "shot $name ($(sips -g pixelWidth -g pixelHeight "$OUT_RAW/${name}.png" 2>/dev/null | awk '/pixel/{printf $2" "}'))"
}

wait_flutter() {
  local pid="$1"
  for _ in $(seq 1 90); do
    if rg -q "Flutter run key commands|A Dart VM Service on" "$LOG" 2>/dev/null; then
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "flutter died:"; tail -80 "$LOG"; return 1
    fi
    sleep 2
  done
  echo "timeout:"; tail -60 "$LOG"; return 1
}

stop_flutter() {
  local pid="${1:-}"
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  [[ -n "$pid" ]] && wait "$pid" 2>/dev/null || true
  pkill -f "flutter_tools.snapshot run" 2>/dev/null || true
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 2
}

run_route() {
  local route="$1"
  local name="$2"
  local wait_s="${3:-16}"
  stop_flutter ""
  : >"$LOG"
  cd "$ROOT"
  flutter run -d "$UDID" -t lib/main_store_shots.dart \
    --dart-define=SKIP_PUSH_INTRO=true \
    --dart-define=SKIP_ONBOARDING=true \
    --dart-define="API_BASE=$API_BASE" \
    --dart-define="STORE_EMAIL=$STORE_EMAIL" \
    --dart-define="STORE_PASSWORD=$STORE_PASSWORD" \
    --dart-define="STORE_PROJECT_ID=$PROJECT_ID" \
    --dart-define="STORE_ROUTE=$route" \
    >"$LOG" 2>&1 &
  local pid=$!
  wait_flutter "$pid"
  sleep "$wait_s"
  shot "$name"
  echo "$pid"
}

cd "$ROOT"
status_bar

echo "==> 01-checkin"
PID=$(run_route "/checkin/$CHECKIN_ID" "01-checkin" 18)
stop_flutter "$PID"

echo "==> 02-board-stuck"
PID=$(run_route "/board?project=$PROJECT_ID" "02-board-stuck" 18)
stop_flutter "$PID"

echo "==> 03-digest"
PID=$(run_route "/digest?project=$PROJECT_ID&period=week" "03-digest" 16)
stop_flutter "$PID"

echo "==> dark appearance"
xcrun simctl ui "$UDID" appearance dark >/dev/null
PID=$(run_route "/checkin/$CHECKIN_ID" "01-checkin-dark" 16)
stop_flutter "$PID"
PID=$(run_route "/digest?project=$PROJECT_ID&period=week" "03-digest-dark" 14)
stop_flutter "$PID"
xcrun simctl ui "$UDID" appearance light >/dev/null

echo "==> warm app"
PID=$(run_route "/board?project=$PROJECT_ID" "00-warm" 14)
sleep 4

echo "==> 06-push-actions"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
sleep 1
PUSH_JSON="$OUT_RAW/checkin-push.json"
python3 - <<PY
import json
from pathlib import Path
payload = {
  "aps": {
    "alert": {
      "title": "Чек-ин",
      "body": "Цифровые сервисы колледжа · ${TASK_TITLE}"
    },
    "sound": "default",
    "category": "TAKT_CHECKIN_ONE",
    "mutable-content": 1,
  },
  "kind": "rhythm_checkin",
  "checkin_id": "$CHECKIN_ID",
  "task_id": "$TASK_ID",
  "action_token": "$ACTION_TOKEN",
  "action_path": "/api/v1/rhythm/push-answer",
  "project_id": "$PROJECT_ID",
}
Path("$PUSH_JSON").write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
print("wrote", "$PUSH_JSON")
PY
xcrun simctl push "$UDID" "$BUNDLE" "$PUSH_JSON" 2>&1 | tee "$OUT_RAW/push.log" || true
sleep 2
shot "06-push-actions"

echo "==> 05-live-activity"
stop_flutter "$PID"
PID=$(run_route "/profile" "00-profile" 10)
stop_flutter "$PID"
xcrun simctl spawn "$UDID" notifyutil -p com.apple.springboard.lockcomplete 2>/dev/null || true
xcrun simctl spawn "$UDID" notifyutil -p com.apple.springboard.lockstate 2>/dev/null || true
sleep 2
shot "05-live-activity"

echo "==> 04-widget"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
sleep 2
shot "04-widget"

echo "RAW → $OUT_RAW"
ls -la "$OUT_RAW"
