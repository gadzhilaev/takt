#!/usr/bin/env bash
# Login as store.review on iOS Simulator and capture App Store screenshots.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${1:-22556E40-53DE-4FDC-B00C-1624C73A5150}"
PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID to the review project UUID}"
STORE_EMAIL="${STORE_EMAIL:?Set STORE_EMAIL (store.review@…)}"
STORE_PASSWORD="${STORE_PASSWORD:?Set STORE_PASSWORD from private credentials}"
OUT_RAW="/tmp/takt-store-shots-raw"
OUT_IOS="$ROOT/store/appstore/screenshots"
OUT_PLAY="$ROOT/store/play/screenshots"
LOG="/tmp/takt-store-shots-flutter.log"

mkdir -p "$OUT_RAW" "$OUT_IOS/iphone-6.3" "$OUT_IOS/iphone-6.5" "$OUT_PLAY"
rm -f "$OUT_RAW"/*.png "$LOG"

shot() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot "$OUT_RAW/${name}.png" >/dev/null
  echo "shot $name ($(sips -g pixelWidth -g pixelHeight "$OUT_RAW/${name}.png" 2>/dev/null | awk '/pixel/{printf $2" "}'))"
}

wait_flutter() {
  local pid="$1"
  for _ in $(seq 1 120); do
    if rg -q "Flutter run key commands|A Dart VM Service on" "$LOG" 2>/dev/null; then
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "flutter run died:"; tail -60 "$LOG"; return 1
    fi
    sleep 2
  done
  echo "timeout waiting for flutter:"; tail -40 "$LOG"; return 1
}

stop_flutter() {
  local pid="${1:-}"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  pkill -f "flutter_tools.snapshot run" 2>/dev/null || true
  xcrun simctl terminate "$UDID" ru.gadzhilaev.takt 2>/dev/null || true
  sleep 2
}

wipe_takt() {
  echo "==> wipe takt session"
  stop_flutter ""
  xcrun simctl uninstall "$UDID" ru.gadzhilaev.takt 2>/dev/null || true
  # Drop keychain rows for this app (survive reinstall on some sims)
  local db="/Users/gadzhilaev/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Keychains/keychain-2-debug.db"
  if [[ -f "$db" ]]; then
    sqlite3 "$db" "DELETE FROM genp WHERE agrp LIKE '%ru.gadzhilaev.takt%';" 2>/dev/null || true
  fi
  sleep 1
  if xcrun simctl listapps "$UDID" | rg -q 'ru.gadzhilaev.takt'; then
    echo "WARN: takt still installed after uninstall"
  else
    echo "takt uninstalled"
  fi
}

run_seeded() {
  local route="$1"
  local name="$2"
  local wait_s="${3:-14}"
  stop_flutter ""
  : >"$LOG"
  cd "$ROOT"
  flutter run -d "$UDID" -t lib/main_store_shots.dart \
    --dart-define=SKIP_PUSH_INTRO=true \
    --dart-define=STORE_EMAIL="$STORE_EMAIL" \
    --dart-define=STORE_PASSWORD="$STORE_PASSWORD" \
    --dart-define=STORE_PROJECT_ID="$PROJECT_ID" \
    --dart-define="STORE_ROUTE=$route" \
    >"$LOG" 2>&1 &
  local pid=$!
  wait_flutter "$pid"
  sleep "$wait_s"
  shot "$name"
  echo "$pid"
}

cd "$ROOT"
wipe_takt

echo "==> 01-login"
: >"$LOG"
flutter run -d "$UDID" --dart-define=SKIP_PUSH_INTRO=true >"$LOG" 2>&1 &
LOGIN_PID=$!
wait_flutter "$LOGIN_PID"
sleep 10
shot "01-login"
stop_flutter "$LOGIN_PID"

echo "==> 04-projects"
PID=$(run_seeded "/projects" "04-projects" 12)
stop_flutter "$PID"

echo "==> 02-board"
PID=$(run_seeded "/board?project=${PROJECT_ID}" "02-board" 16)
stop_flutter "$PID"

echo "==> 03-my-tasks"
PID=$(run_seeded "/my-tasks" "03-my-tasks" 14)
# my-tasks needs an open project — seed sets last project id
stop_flutter "$PID"

echo "==> 05-profile"
PID=$(run_seeded "/profile" "05-profile" 12)
stop_flutter "$PID"

echo "==> export store sizes"
for name in 01-login 02-board 03-my-tasks 04-projects 05-profile; do
  src="$OUT_RAW/${name}.png"
  sips -z 2622 1206 "$src" --out "$OUT_IOS/iphone-6.3/${name}.png" >/dev/null
  sips -z 2556 1179 "$src" --out "$OUT_IOS/iphone-6.5/${name}.png" >/dev/null
  sips -z 2532 1170 "$src" --out "$OUT_PLAY/${name}.png" >/dev/null
done

python3 - <<'PY'
from pathlib import Path
from PIL import Image
src = Path('/Users/gadzhilaev/Documents/Mobile Projects/takt/mobile/store/appstore/screenshots/iphone-6.3')
out = Path('/Users/gadzhilaev/Documents/Mobile Projects/takt/mobile/store/appstore/screenshots/ipad-13')
out.mkdir(parents=True, exist_ok=True)
W, H = 2064, 2752
bg = (247, 247, 245)
for name in ['01-login', '02-board', '03-my-tasks', '04-projects', '05-profile']:
    im = Image.open(src / f'{name}.png').convert('RGB')
    canvas = Image.new('RGB', (W, H), bg)
    margin = 120
    scale = min((W - 2 * margin) / im.width, (H - 2 * margin) / im.height)
    nw, nh = int(im.width * scale), int(im.height * scale)
    canvas.paste(im.resize((nw, nh), Image.Resampling.LANCZOS), ((W - nw) // 2, (H - nh) // 2))
    canvas.save(out / f'{name}.png', optimize=True)
    print('ipad', name)
PY

echo "DONE → $OUT_IOS/iphone-6.3"
open "$OUT_IOS/iphone-6.3"
