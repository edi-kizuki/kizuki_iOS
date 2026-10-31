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
    from remote.kz_guard import api_url, public_key, Refused
    try:
        api_url(values.get("SUPABASE_URL", ""))
    except Refused:
        raise ValueError("Staging backend does not match the approved project.") from None
    bundle_id = "club.kizuki.ios"
    # Decision 43: one app identity. TestFlight (staging) and App Store (production) both use club.kizuki.ios.
    if values.get("PRODUCT_BUNDLE_IDENTIFIER", "") != bundle_id:
        raise ValueError("Release bundle identifier must be club.kizuki.ios.")
    key = values.get("SUPABASE_PUBLISHABLE_KEY", "")
    if not public_key(key):
        raise ValueError("Missing or invalid release public client key.")


if __name__ == "__main__":
    try:
        validate(os.environ)
    except ValueError as error:
        raise SystemExit(f"error: {error}") from None
