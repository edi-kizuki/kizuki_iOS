"""Consumes local CLI status privately. Never prints or writes a service-role key."""
import json
from pathlib import Path
import re
import sys
from local_backend import require_local_url

status = json.load(sys.stdin)
require_local_url(status["API_URL"])
key = status.get("PUBLISHABLE_KEY") or status["ANON_KEY"]
# xcconfig injection is rejected. Actual format is also validated by the app.
if not re.fullmatch(r"[A-Za-z0-9_.-]+", key):
    raise ValueError("Invalid local public client key.")
output = Path(__file__).resolve().parent.parent / "ios/Configuration/Local.private.xcconfig"
output.write_text(f"SUPABASE_PUBLISHABLE_KEY = {key}\n")
output.chmod(0o600)
print("Wrote ignored Local.private.xcconfig with a local public client key.")
