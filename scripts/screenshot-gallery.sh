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
UDID="${KIZUKI_GALLERY_UDID:-$(xcrun simctl list devices available | grep -E 'iPhone 17 Pro \(' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')}"
[[ -n "$UDID" ]] || { echo "No iPhone 17 Pro simulator found." >&2; exit 1; }
[[ "$UDID" != "531CA732-5B3F-444E-9C6C-D2D4585F9B8B" ]] || { echo "Refusing to use the iPhone 16e." >&2; exit 1; }

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
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
