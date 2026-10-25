#!/usr/bin/env bash
# Related: [[012-b01-live-composition-seam]], [[2026-10-25-architecture-concept-v2]].
set -euo pipefail
if [[ "${CONFIGURATION:-}" == Debug ]]; then exit 0; fi
binary="${1:?Pass the built app executable}"
shopt -s nullglob
# Xcode may put app symbols in a sibling .debug.dylib. Inspect that too.
for image in "$binary" "$(dirname "$binary")"/*.dylib; do
  symbols=$(xcrun nm -j "$image")
  if rg -q 'KizukiTestSupport|FixtureBackend|FixtureData|UITestBackend|GalleryScreen|PrototypeRoot' <<< "$symbols"; then
    echo 'error: Debug fixture symbols found in release executable.' >&2
    exit 1
  fi
done
echo 'Release fixture symbol check passed.'
