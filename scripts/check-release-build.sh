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
./scripts/generate-project.sh
derived=".build/ReleaseCheck-$config"
xcodebuild -project ios/Kizuki.xcodeproj -scheme "$scheme" -configuration "$config" \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO \
  KIZUKI_ENVIRONMENT="$environment" SUPABASE_URL="https://$host" \
  SUPABASE_PUBLISHABLE_KEY=sb_publishable_ci_compile_only build
app="$derived/Build/Products/$config-iphonesimulator/Kizuki.app"
python3 scripts/check-release-artifact.py "$app" "$environment"
