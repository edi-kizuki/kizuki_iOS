#!/usr/bin/env bash
# Screenshot every prototype screen on an iPhone 17 Pro simulator into hub/prototypes/.
# Usage: scripts/screenshot-gallery.sh [--no-build] [screen-id ...]
#   No ids = all screens. Example: scripts/screenshot-gallery.sh home suki-crew chat
# Open one screen by hand: xcrun simctl launch booted club.kizuki.ios.local -screen home -fixtures
# Never uses the iPhone 16e. Override the device with KIZUKI_GALLERY_UDID (must be an iPhone 17 Pro class device).
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep in sync with EntryScreen.all (ios/Packages/KizukiKit/Sources/KizukiOnboardingFeature/EntryFlow.swift)
# and GalleryScreen (ios/App/PrototypeRoot.swift). A unit test checks this list.
ALL_SCREENS=(
  splash login eligibility
  onb-handle onb-goal onb-realm onb-roles onb-taste onb-favourites onb-compensation onb-availability onb-city
  onb-primer-notifications onb-primer-location onb-ready
  home project-detail request-form
  search search-post
  suki-crew suki-empty suki-requests suki-sent request-detail suki-create create-project post-collab
  my-projects my-project-owner
  profile profile-other profile-edit report
  chat-list chat
  settings settings-account settings-privacy settings-delete
)

BUILD=1
IDS=()
for arg in "$@"; do
  if [[ "$arg" == "--no-build" ]]; then BUILD=0; else IDS+=("$arg"); fi
done
[[ ${#IDS[@]} -eq 0 ]] && IDS=("${ALL_SCREENS[@]}")

BUNDLE_ID="club.kizuki.ios.local"
DERIVED=".build/DerivedData"
OUT="hub/prototypes"
DATE="${KIZUKI_GALLERY_DATE:-$(date +%Y-%m-%d)}"
PROTECTED_UDID="531CA732-5B3F-444E-9C6C-D2D4585F9B8B"   # iPhone 16e: never touched
# Resolve a UDID to its device name from simctl's own device list. Prints nothing for an unknown UDID.
device_name() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
udid = sys.argv[1].upper()
for devices in json.load(sys.stdin).get("devices", {}).values():
    for device in devices:
        if device.get("udid", "").upper() == udid:
            print(device.get("name", "")); raise SystemExit
' "$1"
}
UDID="${KIZUKI_GALLERY_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
for devices in json.load(sys.stdin).get("devices", {}).values():
    for device in devices:
        if device.get("name") == "iPhone 17 Pro":
            print(device["udid"]); raise SystemExit
')"
fi
[[ -n "$UDID" ]] || { echo "No iPhone 17 Pro simulator found." >&2; exit 1; }
# Case-insensitive: a lowercase protected UDID must not slip through.
UDID="$(printf '%s' "$UDID" | tr '[:lower:]' '[:upper:]')"
[[ "$UDID" != "$PROTECTED_UDID" ]] || { echo "Refusing to use the iPhone 16e." >&2; exit 1; }
# Only a real iPhone 17 Pro class simulator is accepted, checked before any boot, install or terminate.
DEVICE_NAME="$(device_name "$UDID")"
[[ "$DEVICE_NAME" == "iPhone 17 Pro" || "$DEVICE_NAME" == "iPhone 17 Pro Max" ]] || {
  echo "Refusing $UDID: device is '${DEVICE_NAME:-unknown}', not an iPhone 17 Pro class simulator." >&2; exit 1; }

# Always undo the status-bar override and stop the app, including on failure or interrupt.
cleanup() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" || true
if [[ $BUILD -eq 1 ]]; then
  ./scripts/generate-project.sh >/dev/null
  xcodebuild -project ios/Kizuki.xcodeproj -scheme Kizuki-Local -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
    -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build -quiet
fi
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Kizuki.app"
xcrun simctl install "$UDID" "$APP"
mkdir -p "$OUT"
# Same status bar on every shot.
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 >/dev/null 2>&1 || true

for id in "${IDS[@]}"; do
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -screen "$id" -fixtures >/dev/null
  sleep 2.2   # an explicit -screen splash does not auto-advance
  xcrun simctl io "$UDID" screenshot "$OUT/$DATE-$id.png" >/dev/null 2>&1
  echo "$OUT/$DATE-$id.png"
done
