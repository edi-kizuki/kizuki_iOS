#!/usr/bin/env python3
"""Inspect a built Staging or Release Kizuki.app. Fails if prototype, fixture or Debug-only code or data shipped.

Usage: check-release-artifact.py <path/to/Kizuki.app> <staging|production>
Prints only check names, never URLs or keys.
"""
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

BUNDLE_ID = "club.kizuki.ios"  # decision 43: one app identity
HOSTS = {"staging": "ankgfqkgflcalmlreetu.supabase.co", "production": "enosggckdxjiaqtxalhg.supabase.co"}

# Type, module and launch-argument names that exist only in fixture or Debug code (matches mangled Swift symbols too).
FORBIDDEN_SYMBOLS = [b"FixtureBackend", b"FixtureData", b"FixtureIDs", b"FixtureAvatarIDs", b"UITestBackend", b"PrototypeRoot",
                     b"KizukiTestSupport", b"GalleryScreen", b"--ui-testing", b"-fixtures"]
# Visible prototype copy and synthetic account data. Live screens must never ship these.
FORBIDDEN_STRINGS = [b"mika@example.com", b"Prototype", b"prototype", b"Nothing is sent", b"Nothing was changed",
                     b"Your account was deleted", b"fixture data only", b"Sample copy", b"sample copy", b"mock toggles"]
DEBUG_ARTIFACTS = [".debug.dylib", "__preview.dylib", ".xctest", "Info-Local.plist"]
SKIP_SUFFIXES = {".png", ".jpg", ".car", ".ttf", ".nib", ".storyboardc", ".mom", ".momd"}


MACHO_MAGICS = {b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe"}


def code_bytes(path):
    """File contents, with debug-map entries (build-machine object paths) stripped from Mach-O binaries.

    Those entries name linked object files by path; they are not code or data and Archive strips them. Everything else
    (symbols, Swift metadata, string literals) is still scanned.
    """
    data = path.read_bytes()
    if data[:4] in MACHO_MAGICS and shutil.which("strip"):
        with tempfile.TemporaryDirectory() as scratch:
            copy = Path(scratch) / "binary"
            copy.write_bytes(data)
            if subprocess.run(["strip", "-S", str(copy)], capture_output=True).returncode == 0:
                return copy.read_bytes()
    return data


def inspect_app(app, expected_environment):
    app = Path(app)
    problems = []
    info_path = app / "Info.plist"
    if not info_path.is_file():
        return ["Info.plist missing"]
    info = plistlib.loads(info_path.read_bytes())
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        problems.append("bundle identifier is not club.kizuki.ios")
    if info.get("KizukiEnvironment") != expected_environment:
        problems.append("KizukiEnvironment does not match the expected environment")
    url = str(info.get("SupabaseURL", ""))
    if url != f"https://{HOSTS[expected_environment]}":
        problems.append("SupabaseURL is not the approved project for this environment")
    key = str(info.get("SupabasePublishableKey", ""))
    if not re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{8,}", key) and key.count(".") != 2:
        problems.append("SupabasePublishableKey is missing or not a public client key")
    executable = info.get("CFBundleExecutable", "Kizuki")
    if not (app / executable).is_file():
        problems.append("app executable missing")
    for path in sorted(app.rglob("*")):
        relative = str(path.relative_to(app))
        if any(marker in relative for marker in DEBUG_ARTIFACTS):
            problems.append(f"Debug-only artifact present: {relative}")
        if not path.is_file() or path.suffix in SKIP_SUFFIXES:
            continue
        data = code_bytes(path)
        for needle in FORBIDDEN_SYMBOLS + FORBIDDEN_STRINGS:
            if needle in data:
                problems.append(f"forbidden {'symbol' if needle in FORBIDDEN_SYMBOLS else 'string'} in {relative}: {needle.decode()}")
    return problems


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[2] not in HOSTS:
        raise SystemExit("usage: check-release-artifact.py <Kizuki.app> <staging|production>")
    found = inspect_app(sys.argv[1], sys.argv[2])
    for problem in found:
        print(f"error: {problem}", file=sys.stderr)
    if found:
        raise SystemExit(1)
    print(f"ok: {sys.argv[1]} passes the {sys.argv[2]} artifact check")
