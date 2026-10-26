#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
check_dir=$(mktemp -d "$PWD/.build/runtime-guard.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
cat > "$check_dir/Guard.swift" <<'SWIFT'
import Foundation
@main enum GuardCheck {
    static func main() throws {
        let key = "sb_publishable_compile_check_only"
        for (environment, url) in [(AppEnvironment.local, "http://127.0.0.1:54321"),
                                   (.production, "https://enosggckdxjiaqtxalhg.supabase.co"),
                                   (.staging, "https://other.supabase.co")] {
            do {
                _ = try AppConfiguration(environment: environment, url: url, publishableKey: key)
                fatalError("Non-Debug runtime accepted an unsafe environment")
            } catch ConfigurationError.unsafeEnvironment {}
        }
        _ = try AppConfiguration(environment: .staging, url: "https://ankgfqkgflcalmlreetu.supabase.co", publishableKey: key)
        print("Non-Debug runtime configuration checks passed (4 cases).")
    }
}
SWIFT
xcrun swiftc -O -parse-as-library ios/Packages/KizukiKit/Sources/KizukiCore/AppConfiguration.swift "$check_dir/Guard.swift" -o "$check_dir/check"
"$check_dir/check"
