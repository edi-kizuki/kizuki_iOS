#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen 2.46.0 or newer.' >&2; exit 1; }
xcodegen generate --spec project.yml --project ios
lock_dir=ios/Kizuki.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$lock_dir"
cp ios/Package.resolved "$lock_dir/Package.resolved"
