#!/usr/bin/env python3
"""G14 remote effect boundary. Related: [[014-b03-environment-pinning]]."""
from pathlib import Path
import re
import sys
from remote.kz_guard import DENIED_REFS

ROOT = Path(__file__).resolve().parents[1]
# Split constants so the scanner can inspect its own source without exemptions.
PATTERNS = [r'\b' + a + r'\s+' + b + r'\b' for a, b in
            [("db", "push"), ("functions", "deploy"), ("secrets", "set"), ("supabase", "link"), ("config", "push")]]
PATTERNS += [re.escape("--" + flag) for flag in ("db-url", "project-ref")]
PATTERNS += [re.escape("api." + "supabase.com"), *DENIED_REFS]


def check(root=ROOT):
    errors = []
    for directory in (root / "scripts", root / ".github/workflows"):
        for path in directory.rglob("*"):
            if not path.is_file() or path.suffix not in {".py", ".sh", ".yml", ".yaml", ".ts", ".js", ".mjs", ".json"}: continue
            if path.is_relative_to(root / "scripts/remote"): continue
            if any(re.search(pattern, path.read_text(), re.I) for pattern in PATTERNS):
                errors.append("remote mutation outside gateway: " + str(path.relative_to(root)))
    return errors


if __name__ == "__main__":
    problems = check()
    print("\n".join(problems) if problems else "Remote mutation boundary OK.")
    sys.exit(bool(problems))
