#!/usr/bin/env bash
# Build a release-type configuration (Staging or Release) for a generic simulator with a clearly synthetic public key,
# then inspect the artifact. The build is never launched and contacts no backend. Usage: check-release-build.sh Staging|Release
set -euo pipefail
cd "$(dirname "$0")/.."
config="${1:?usage: check-release-build.sh Staging|Release}"
case "$config" in
  Staging) scheme=Kizuki-Staging; environment=staging; host=ankgfqkgflcalmlreetu.supabase.co ;;
  Release) scheme=Kizuki-Production; environment=production; host=enosggckdxjiaqtxalhg.supabase.co ;;
  *) echo "Unknown configuration: $config" >&2; exit 2 ;;
esac
# Production is deliberately unbuildable in v0. Verify the real Xcode prebuild barrier.
./scripts/generate-project.sh
derived=".build/ReleaseCheck-$config"
mkdir -p .build
log=".build/release-check-$config.log"
set +e
xcodebuild -project ios/Kizuki.xcodeproj -scheme "$scheme" -configuration "$config" \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO \
  KIZUKI_ENVIRONMENT="$environment" SUPABASE_URL="https://$host" \
  SUPABASE_PUBLISHABLE_KEY=sb_publishable_ci_compile_only build >"$log" 2>&1
status=$?
set -e
if [[ "$config" == Release ]]; then
  if [[ "$status" != 0 ]] && /usr/bin/grep -Fq 'error: Production configuration is disabled in v0.' "$log"; then
    echo 'ok: Release build refused production in the configuration validator'
    exit 0
  fi
  echo 'error: Release did not fail at the production barrier; see build log' >&2
  exit 1
fi
if [[ "$status" != 0 ]]; then tail -n 60 "$log"; exit "$status"; fi
app="$derived/Build/Products/$config-iphonesimulator/Kizuki.app"
python3 scripts/check-release-artifact.py "$app" "$environment"
