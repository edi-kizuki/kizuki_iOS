"""Fail archives closed without printing URLs or keys."""
import base64
import json
import os
import re
from urllib.parse import urlsplit


def validate(values):
    environment = values.get("KIZUKI_ENVIRONMENT", "")
    expected = {"Staging": "staging", "Release": "production"}.get(values.get("CONFIGURATION"))
    if expected is None or environment != expected:
        raise ValueError("Build configuration and backend environment do not match.")
    url = urlsplit(values.get("SUPABASE_URL", ""))
    host = url.hostname or ""
    production = "enosggckdxjiaqtxalhg.supabase.co"
    if (url.scheme != "https" or url.username or url.password or url.query or url.fragment
            or url.path not in {"", "/"} or url.port is not None):
        raise ValueError("Invalid release backend URL.")
    if environment == "production" and host != production:
        raise ValueError("Production backend does not match the approved project.")
    if environment == "staging" and (host == production or not host.endswith(".supabase.co")):
        raise ValueError("Staging backend must be separate from production.")
    key = values.get("SUPABASE_PUBLISHABLE_KEY", "")
    public = re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{8,}", key) is not None
    if not public:
        try:
            segments = key.split(".")
            public = (len(segments) == 3 and bool(segments[2])
                      and json.loads(base64.urlsafe_b64decode(segments[1] + "=" * (-len(segments[1]) % 4)))["role"] == "anon")
        except (ValueError, KeyError, UnicodeError):
            public = False
    if not public:
        raise ValueError("Missing or invalid release public client key.")


if __name__ == "__main__":
    try:
        validate(os.environ)
    except ValueError as error:
        raise SystemExit(f"error: {error}") from None
