#!/usr/bin/env python3
"""G12/A12/E6 drift gates. Related: [[014-b03-environment-pinning]]."""
import hashlib
from pathlib import Path
import re
import sys
from remote.kz_guard import STAGING_REF, STAGING_API_HOST, DENIED_REFS, PIN, BOOTSTRAP_SHA256

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT):
    errors = []
    swift = root / "ios/Packages/KizukiKit/Sources/KizukiCore/BackendAllowlist.swift"
    mirrors = [swift, root / "scripts/remote/kz_guard.py", root / "supabase/functions/_shared/env_guard.ts"]
    for path in mirrors:
        text = path.read_text()
        # Parse the declared values, not occurrences in comments or tests.
        for names, expected in [(r"(?:stagingRef|STAGING_REF)", STAGING_REF),
                                (r"(?:stagingHost|STAGING_API_HOST)", STAGING_API_HOST)]:
            match = re.search(names + r'\s*=\s*"([^"]+)"', text)
            if not match or match[1] != expected: errors.append(f"pin drift: {path.relative_to(root)}")
        denied = re.search(r'(?:deniedRefs|DENIED_REFS)\s*=\s*\[([^\]]*)\]', text)
        if not denied or re.findall(r'"([^"]+)"', denied[1]) != DENIED_REFS:
            errors.append(f"denylist drift: {path.relative_to(root)}")
    config = (root / "ios/Configuration/Staging.xcconfig").read_text()
    if re.findall(r'^SUPABASE_URL\s*=\s*(.*)$', config, re.M) != ["https:/$()/" + STAGING_API_HOST]: errors.append("staging URL drift")
    production = (root / "ios/Configuration/Production.xcconfig").read_text()
    if ".supabase.co" in production or "private.xcconfig" in production or re.findall(r'^SUPABASE_URL\s*=([^\n]*)$', production, re.M) != [""]:
        errors.append("production configuration enabled")
    lines = (root / "scripts/remote/staging.pin").read_text().splitlines()
    entries = [line.split("=", 1) for line in lines if line and not line.startswith("#")]
    if len(entries) != len(PIN) or dict(entries) != PIN: errors.append("pooler pin drift")
    if hashlib.sha256((root / "supabase/bootstrap/env_marker.sql").read_bytes()).hexdigest() != BOOTSTRAP_SHA256: errors.append("bootstrap hash drift")
    for path in [*(root / "ios/App").rglob("*.swift"), *(root / "ios/Packages").rglob("*.swift")]:
        text = path.read_text()
        if re.search(r'\bSupabaseClient\s*\(', text) and path.name != "GuardedSupabase.swift": errors.append(f"unguarded client: {path.name}")
        if any(ref in text for ref in DENIED_REFS) and path != swift: errors.append(f"denylist outside allowlist: {path.name}")
    for path in (root / "supabase/migrations").glob("*.sql"):
        text = re.sub(r'--[^\n]*', '', path.read_text())
        if re.search(r'\b(?:create|alter|drop|insert\s+into|update|delete\s+from|truncate|grant|revoke)\b[^;]*\bkizuki_env\b', text, re.I):
            errors.append(f"marker mutation in migration: {path.name}")
    return errors


if __name__ == "__main__":
    problems = check()
    print("\n".join(problems) if problems else "Environment pins, client factory and marker isolation OK.")
    sys.exit(bool(problems))
