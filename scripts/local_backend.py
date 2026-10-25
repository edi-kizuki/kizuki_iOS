"""Strict loopback-only guard shared by local setup and integration tests."""
from urllib.parse import urlsplit


def require_local_url(value):
    parsed = urlsplit(value)
    if not (parsed.scheme == "http" and parsed.hostname in {"127.0.0.1", "localhost"}
            and parsed.port == 54321 and not parsed.username and not parsed.password
            and parsed.path in {"", "/"} and not parsed.query and not parsed.fragment):
        raise ValueError("Refusing non-local Supabase endpoint; no requests sent.")
    return value.rstrip("/")
