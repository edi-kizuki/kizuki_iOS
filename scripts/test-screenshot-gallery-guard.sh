#!/usr/bin/env bash
# Safety tests for scripts/screenshot-gallery.sh using a fake xcrun. No real simulator is touched.
set -uo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
PROTECTED=531CA732-5B3F-444E-9C6C-D2D4585F9B8B
GOOD=491ABF02-99F0-4FA8-AC1B-AFC92425C693
OTHER=11111111-2222-3333-4444-555555555555
mkdir "$work/bin"
cat > "$work/bin/xcrun" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
if [[ "$1 $2 $3" == "simctl list devices" ]]; then
  cat <<JSON
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[
 {"udid":"531CA732-5B3F-444E-9C6C-D2D4585F9B8B","name":"iPhone 16e"},
 {"udid":"491ABF02-99F0-4FA8-AC1B-AFC92425C693","name":"iPhone 17 Pro"},
 {"udid":"11111111-2222-3333-4444-555555555555","name":"iPhone 16"}]}}
JSON
  exit 0
fi
[[ "$2" == launch && -n "${FAKE_FAIL_LAUNCH:-}" ]] && exit 1
exit 0
FAKE
chmod +x "$work/bin/xcrun"
failures=0
check() { if [[ "$2" == ok ]]; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi; }
mutating() { grep -qE 'simctl (boot|bootstatus|install|terminate|launch|status_bar|io)' "$work/log"; }

for udid in "$PROTECTED" "$(printf '%s' "$PROTECTED" | tr '[:upper:]' '[:lower:]')" "$OTHER" "99999999-9999-9999-9999-999999999999"; do
  : > "$work/log";
  FAKE_LOG="$work/log" PATH="$work/bin:$PATH" KIZUKI_GALLERY_UDID="$udid" ./scripts/screenshot-gallery.sh --no-build home >"$work/out" 2>&1; code=$?
  if [[ $code -ne 0 ]] && ! mutating; then check "refuses $udid before touching the device" ok; else check "refuses $udid before touching the device" bad; fi
done

: > "$work/log"
FAKE_FAIL_LAUNCH=1 FAKE_LOG="$work/log" PATH="$work/bin:$PATH" KIZUKI_GALLERY_UDID="$GOOD" ./scripts/screenshot-gallery.sh --no-build home >"$work/out" 2>&1; code=$?
if [[ $code -ne 0 ]] && grep -q "status_bar $GOOD clear" "$work/log" && grep -q "terminate $GOOD" "$work/log"; then
  check "clears status bar and stops the app after a launch failure" ok
else check "clears status bar and stops the app after a launch failure" bad; fi
exit $((failures > 0))
