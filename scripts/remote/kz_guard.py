"""Offline pins and refusal vocabulary. Related: [[014-b03-environment-pinning]]."""
import base64
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit, parse_qsl

STAGING_REF = "ankgfqkgflcalmlreetu"
STAGING_API_HOST = "ankgfqkgflcalmlreetu.supabase.co"
DENIED_REFS = ["enosggckdxjiaqtxalhg"]
STAGING_POOLER_HOST = "aws-0-eu-west-1.pooler.supabase.com"
STAGING_DIRECT_DB_HOST = "db.ankgfqkgflcalmlreetu.supabase.co"
BOOTSTRAP_SHA256 = "1e4af2adf050092edad947c23d571a6edf83547c22f7c3d9fa181e1c1055dc4a"
ROOT = Path(__file__).resolve().parents[2]
COMMANDS = {"doctor", "verify", "bootstrap", "migrate", "vault-set", "seed", "auth-config", "functions-deploy", "secrets-set"}
PIN = dict(project_ref=STAGING_REF, api_host=STAGING_API_HOST, pooler_host=STAGING_POOLER_HOST,
           pooler_port="6543", session_port="5432", database="postgres", user="postgres." + STAGING_REF,
           denied_ref=DENIED_REFS[0])


class Refused(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def require(condition, code):
    if not condition:
        raise Refused(code)


def denied(value):
    return any(ref in str(value).lower() for ref in DENIED_REFS)


def api_url(value):
    require(not denied(value), "E_REF_DENIED")
    try:
        parsed = urlsplit(value)
        require(parsed.scheme == "https" and parsed.hostname == STAGING_API_HOST
                and parsed.netloc.lower() == STAGING_API_HOST and not parsed.path
                and not parsed.query and not parsed.fragment and value.lower() == "https://" + STAGING_API_HOST,
                "E_HOST_NOT_ALLOWED")
    except ValueError:
        raise Refused("E_HOST_NOT_ALLOWED") from None
    return value


def public_key(value):
    if re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{8,}", value):
        return True
    payload = jwt(value)
    return payload is not None and payload.get("role") == "anon" and payload.get("ref", STAGING_REF) == STAGING_REF


def jwt(value):
    try:
        parts = value.split(".")
        if len(parts) != 3 or not parts[2]: return None
        result = json.loads(base64.urlsafe_b64decode(parts[1] + "=" * (-len(parts[1]) % 4)))
        return result if isinstance(result, dict) else None
    except (ValueError, UnicodeError):
        return None


def validate_dsn(value):
    try:
        p = urlsplit(value)
        # The only accepted query is TLS enforcement; duplicate/query overrides fail.
        require(p.scheme in {"postgres", "postgresql"} and not p.fragment
                and p.port == 5432 and p.path == "/postgres"
                and parse_qsl(p.query, keep_blank_values=True) == [("sslmode", "require")]
                and ((p.hostname == STAGING_POOLER_HOST and p.username == "postgres." + STAGING_REF)
                     or (p.hostname == STAGING_DIRECT_DB_HOST and p.username == "postgres")), "E_POOLER")
        require(not denied(value), "E_POOLER")
    except (ValueError, TypeError):
        raise Refused("E_POOLER") from None


def static_checks(argv, env, root=ROOT, home=None):
    require(bool(argv) and argv[0] in COMMANDS, "E_OVERRIDE")
    command = argv[0]
    args = argv[1:]
    if command == "bootstrap":
        require(not args or (len(args) == 2 and args[0] == "--witness" and bool(args[1]) and not args[1].startswith("-")), "E_OVERRIDE")
    elif command == "vault-set":
        require(len(args) == 1 and re.fullmatch(r"[a-z][a-z0-9_]{0,63}", args[0]), "E_OVERRIDE")
    else:
        require(not args, "E_OVERRIDE")
    lowered = {k.lower(): v for k, v in env.items()}
    require("supabase_access_token" not in lowered, "E_TOKEN_PRESENT")
    require(not any(k in lowered for k in ("http_proxy", "https_proxy", "all_proxy")), "E_PROXY")
    require(not any(k.startswith("pg") or k in {"database_url", "supabase_project_id", "supabase_db_url", "supabase_db_password"}
                    for k in lowered), "E_OVERRIDE")
    require(not any(denied(v) for v in [*argv, *env.values()]), "E_REF_DENIED")
    if command == "bootstrap":
        require(not any(lowered.get(k, "").lower() not in {"", "0", "false"} for k in ("ci", "github_actions")), "E_CI_BOOTSTRAP")
    try:
        lines = (root / "scripts/remote/staging.pin").read_text().splitlines()
        entries = [line.split("=", 1) for line in lines if line and not line.startswith("#")]
        require(len(entries) == len(PIN) and dict(entries) == PIN, "E_POOLER")
        temp = root / "supabase/.temp"
        if temp.exists():
            for path in temp.iterdir():
                if path.is_file():
                    value = path.read_text()
                    require(not denied(value), "E_REF_DENIED")
                    if path.name == "project-ref": require(value.strip() == STAGING_REF, "E_LINK_STATE")
                    if path.name == "pooler-url":
                        try: validate_dsn(value.strip())
                        except Refused: raise Refused("E_LINK_STATE") from None
        pgpass = (home or Path.home()) / ".pgpass"
        if pgpass.exists():
            for line in pgpass.read_text().splitlines():
                if line and not line.startswith("#") and line.split(":", 1)[0] in {"*", STAGING_POOLER_HOST, STAGING_DIRECT_DB_HOST}:
                    require(not denied(line), "E_REF_DENIED")
        if command == "bootstrap":
            require(hashlib.sha256((root / "supabase/bootstrap/env_marker.sql").read_bytes()).hexdigest() == BOOTSTRAP_SHA256, "E_BOOTSTRAP_FILE")
    except (OSError, ValueError):
        raise Refused("E_LINK_STATE") from None
    api_url("https://" + PIN["api_host"])
    validate_dsn(f"postgresql://{PIN['user']}@{PIN['pooler_host']}:{PIN['session_port']}/postgres?sslmode=require")
    return command


def state(snapshot):
    if snapshot["marker_exists"]:
        rows = snapshot["rows"]
        require(len(rows) == 1 and rows[0].get("environment") == "staging"
                and rows[0].get("project_ref") == STAGING_REF and rows[0].get("api_host") == STAGING_API_HOST,
                "E_MARKER_WRONG")
        return "S1"
    require(not snapshot["user_objects"] and not snapshot["versions"], "E_NOT_PRISTINE")
    return "S0"
