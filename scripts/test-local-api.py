"""Local-only Auth/PostgREST integration. Synthetic users are removed in finally."""
import json
import secrets
import sys
import urllib.error
import urllib.request
import uuid
from local_backend import require_local_url

status = json.load(sys.stdin)
base = require_local_url(status["API_URL"])  # Check BEFORE using keys or sending anything.
public_key = status.get("PUBLISHABLE_KEY") or status["ANON_KEY"]
admin_key = status["SERVICE_ROLE_KEY"]  # Local CLI output only; memory only; never printed.

# No redirects: a local server must never redirect test credentials to another host.
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)

def request(path, *, token=None, body=None, method="GET", admin=False):
    key = admin_key if admin else public_key
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, method=method, headers={
        "apikey": key, "Authorization": "Bearer " + (token or key), "Content-Type": "application/json"
    })
    try:
        with opener.open(req, timeout=10) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        # Do not log response bodies or headers: they may contain auth material.
        raise RuntimeError(f"Local API check failed with HTTP {error.code}") from None

users = []
try:
    sessions = []
    for _ in range(2):
        email = f"foundation-{uuid.uuid4()}@example.invalid"
        password = secrets.token_urlsafe(24)
        user = request("/auth/v1/admin/users", admin=True, method="POST", body={
            "email": email, "password": password, "email_confirm": True
        })
        users.append(user["id"])
        sessions.append(request("/auth/v1/token?grant_type=password", method="POST", body={
            "email": email, "password": password
        })["access_token"])
    own = request("/rest/v1/profiles?select=id,handle,display_handle,avatar_path", token=sessions[0])
    assert len(own) == 1 and own[0]["id"] == users[0], "Own-profile RLS failed"
    other = request(f"/rest/v1/profiles?select=id&id=eq.{users[1]}", token=sessions[0])
    assert other == [], "Another profile leaked"
    private = request("/rest/v1/profile_settings?select=profile_id", token=sessions[0])
    assert len(private) == 1 and private[0]["profile_id"] == users[0], "Private settings leaked"
    print("Local Auth, profile provisioning, own read and cross-user RLS checks passed.")
finally:
    for user_id in users:
        request(f"/auth/v1/admin/users/{user_id}", admin=True, method="DELETE")
