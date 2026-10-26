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
    if environment == "production":
        raise ValueError("Production configuration is disabled in v0.")
    url = urlsplit(values.get("SUPABASE_URL", ""))
    host = url.hostname or ""
    production = "enosggckdxjiaqtxalhg.supabase.co"
    staging = "ankgfqkgflcalmlreetu.supabase.co"
    bundle_id = "club.kizuki.ios"
    if (url.scheme != "https" or url.username or url.password or url.query or url.fragment
            or url.path not in {"", "/"} or url.port is not None):
        raise ValueError("Invalid release backend URL.")
    if environment == "production" and host != production:
        raise ValueError("Production backend does not match the approved project.")
    if environment == "staging" and host != staging:
        raise ValueError("Staging backend does not match the approved project.")
    # Decision 43: one app identity. TestFlight (staging) and App Store (production) both use club.kizuki.ios.
    if values.get("PRODUCT_BUNDLE_IDENTIFIER", "") != bundle_id:
        raise ValueError("Release bundle identifier must be club.kizuki.ios.")
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
