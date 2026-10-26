#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/generate-project.sh
# Only the Local scheme is tested. No production credentials or live test accounts.
# Override the destination for an installed iOS simulator; iOS 17 runtime is also recommended.
destination="${KIZUKI_TEST_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
mkdir -p .build
xcodebuild -project ios/Kizuki.xcodeproj -scheme Kizuki-Local -configuration Debug \
  -destination "$destination" -derivedDataPath .build/DerivedData \
  -resultBundlePath ".build/Tests-$(date +%Y%m%d-%H%M%S).xcresult" \
  -parallel-testing-enabled NO -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO test
