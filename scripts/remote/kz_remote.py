"""Staging-only gateway. Related: [[014-b03-environment-pinning]], [[031-b20-staging-deploy-seed]]."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.request
import ssl

from kz_guard import (ROOT, PIN, BOOTSTRAP_SHA256, STAGING_REF, STAGING_API_HOST,
                      Refused, require, static_checks, state, jwt, denied)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise Refused("E_REDIRECT")


class API:
    def __init__(self, secret):
        payload = jwt(secret)
        require((secret.startswith("sb_secret_") and len(secret) > 20)
                or (payload is not None and payload.get("ref") == STAGING_REF and payload.get("role") == "service_role"),
                "E_CREDENTIAL")
        self.secret = secret
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
            urllib.request.HTTPSHandler(context=ssl.create_default_context()))

    def call(self, path, body=None):
        require(path.startswith("/") and not path.startswith("//") and not denied(path), "E_HOST_NOT_ALLOWED")
        url = "https://" + STAGING_API_HOST + path
        headers = {"apikey": self.secret, "Content-Type": "application/json"}
        if jwt(self.secret): headers["Authorization"] = "Bearer " + self.secret
        request = urllib.request.Request(url, headers=headers,
            data=None if body is None else json.dumps(body).encode())
        try:
            with self.opener.open(request, timeout=15) as response:
                require(response.url == url, "E_REDIRECT")
                require(response.status == 200, "E_API")
                return json.load(response)
        except Refused: raise
        except Exception: raise Refused("E_API") from None

    def identity(self):
        self.call("/auth/v1/admin/users?per_page=1")


def keychain(name):
    # Values stay in memory. No shell, environment export, file, or diagnostic containing credentials.
    result = subprocess.run(["security", "find-generic-password", "-s", name, "-a", "kizuki", "-w"],
                            capture_output=True, check=False)
    require(result.returncode == 0, "E_CREDENTIAL")
    value = result.stdout.decode().rstrip("\n")
    require(bool(value) and not denied(value), "E_CREDENTIAL")
    return value


def credentials(env):
    if env.get("GITHUB_ACTIONS") == "true":
        require(env.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
                and env.get("GITHUB_REF") == "refs/heads/main", "E_CI_CONTEXT")
        password = env.get("KIZUKI_STAGING_DB_PASSWORD", "")
        secret = env.get("KIZUKI_STAGING_SECRET_KEY", "")
        require(bool(password) and bool(secret), "E_CREDENTIAL")
        return password, secret
    return keychain("kizuki-staging-db"), keychain("kizuki-staging-secret")


class SqlDriver:
    """One pinned TLS session. No libpq command, CLI token store, or password in argv."""
    def __init__(self, password):
        try:
            import psycopg
        except ImportError:
            raise Refused("E_DRIVER_MISSING") from None
        try:
            self.connection = psycopg.connect(host=PIN["pooler_host"], port=int(PIN["session_port"]),
                dbname=PIN["database"], user=PIN["user"], password=password, sslmode="require",
                connect_timeout=10, autocommit=True, prepare_threshold=None,
                options="-c statement_timeout=30000 -c lock_timeout=10000")
            require(self.connection.execute("select current_user").fetchone()[0] == "postgres", "E_DB_ROLE")
        except Refused: raise
        except Exception: raise Refused("E_DATABASE") from None

    def close(self): self.connection.close()

    def snapshot(self):
        with self.connection.transaction():
            c = self.connection
            marker_exists = c.execute("select to_regclass('kizuki_env.environment_marker') is not null").fetchone()[0]
            rows = c.execute("select environment, project_ref, api_host from kizuki_env.environment_marker").fetchall() if marker_exists else []
            user_objects = c.execute("""select exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                where n.nspname in ('public','private','kizuki_env') and c.relkind in ('r','p','v','m','f'))""").fetchone()[0]
            versions_exist = c.execute("select to_regclass('supabase_migrations.schema_migrations') is not null").fetchone()[0]
            versions = [row[0] for row in c.execute("select version from supabase_migrations.schema_migrations order by version").fetchall()] if versions_exist else []
            fingerprint = c.execute("select pg_postmaster_start_time()::text").fetchone()[0]
            return dict(marker_exists=marker_exists, rows=[dict(zip(("environment", "project_ref", "api_host"), row)) for row in rows],
                        user_objects=user_objects, versions=versions, fingerprint=fingerprint)

    def bootstrap(self, content, witness):
        # Re-check the same session immediately before the self-guarded transaction.
        snapshot = self.snapshot()
        require(state(snapshot) == "S0", "E_MARKER_WRONG")
        require(snapshot["fingerprint"] == witness, "E_WITNESS")
        self.connection.execute("select set_config('kizuki.bootstrap_environment', 'staging', false)")
        self.connection.execute("select set_config('kizuki.bootstrap_sha256', %s, false)", (BOOTSTRAP_SHA256,))
        self.connection.execute(content.decode(), prepare=False)

    def migrate(self, migrations):
        for version, name, content in migrations:
            with self.connection.transaction():
                self.connection.execute("select pg_advisory_xact_lock(703003)")
                require(state(self.snapshot()) == "S1", "E_MARKER_WRONG")
                self.connection.execute("create schema if not exists supabase_migrations")
                self.connection.execute("""create table if not exists supabase_migrations.schema_migrations
                    (version text primary key, statements text[], name text)""")
                if self.connection.execute("select 1 from supabase_migrations.schema_migrations where version=%s", (version,)).fetchone():
                    continue
                self.connection.execute(content, prepare=False)
                self.connection.execute("insert into supabase_migrations.schema_migrations(version, name, statements) values (%s,%s,%s)",
                                        (version, name, [content]))

    def vault_set(self, name, value):
        with self.connection.transaction():
            require(state(self.snapshot()) == "S1", "E_MARKER_WRONG")
            row = self.connection.execute("select id from vault.secrets where name=%s", (name,)).fetchone()
            if row:
                self.connection.execute("select vault.update_secret(%s, %s, %s)", (row[0], value, name))
            else:
                self.connection.execute("select vault.create_secret(%s, %s)", (value, name))


def migrations(root):
    result = []
    for path in sorted((root / "supabase/migrations").glob("*.sql")):
        match = re.fullmatch(r"(\d{14})_(.+)\.sql", path.name)
        require(match is not None, "E_MIGRATIONS")
        result.append((*match.groups(), path.read_text()))
    require(len({r[0] for r in result}) == len(result), "E_MIGRATIONS")
    return result


CHECKLIST = """Dashboard checklist (staging only; no management token):
- Auth: enable email confirmations; minimum password length 10; numeric OTP email template.
- Auth: configure the reviewed redirect URLs, rate limits and SMTP before sign-up smoke.
- Functions: deploy reviewed function sources through the staging dashboard when a consumer exists.
- Function secrets: set required project-scoped secrets in the staging dashboard; never paste them into logs.
- Verify auth settings and smoke tests in B20. No changes were made."""


def run(argv, env, root=ROOT, home=None, driver_factory=SqlDriver, api_factory=API, credential_source=credentials):
    command = static_checks(argv, env, root, home)
    if command == "doctor":
        print("Static pins OK. SQL driver: psycopg 3.2.13 (install remote/requirements.txt before B20).")
        return
    if command == "bootstrap": require(len(argv) == 3, "E_WITNESS")
    if command in {"auth-config", "functions-deploy", "secrets-set"}:
        print(CHECKLIST)
        return
    sql_files = migrations(root)
    # Read and hash the exact bytes that will execute; no file race between guard and execution.
    content = (root / "supabase/bootstrap/env_marker.sql").read_bytes() if command == "bootstrap" else None
    if content is not None: require(hashlib.sha256(content).hexdigest() == BOOTSTRAP_SHA256, "E_BOOTSTRAP_FILE")
    password, secret = credential_source(env)
    api = api_factory(secret)
    api.identity()
    driver = driver_factory(password)
    try:
        snapshot = driver.snapshot()
        current = state(snapshot)
        versions = [m[0] for m in sql_files]
        require(all(v in versions for v in snapshot["versions"]), "E_MIGRATIONS")
        if command == "verify":
            print("state=" + current)
            print("witness=" + snapshot["fingerprint"])
            print("migrations=" + ("current" if snapshot["versions"] == versions else "pending"))
            settings = api.call("/auth/v1/settings")
            print("auth_email_enabled=" + str(settings.get("external", {}).get("email") is True).lower())
            print("Dashboard-only auth settings require B20 smoke verification.")
        elif command == "bootstrap":
            require(current == "S0", "E_MARKER_WRONG")
            require(argv[2] == snapshot["fingerprint"], "E_WITNESS")
            driver.bootstrap(content, argv[2])
            require(state(driver.snapshot()) == "S1", "E_MARKER_WRONG")
        else:
            require(current == "S1", "E_MARKER_ABSENT")
            if command == "migrate": driver.migrate(sql_files)
            elif command == "vault-set":
                # stdin only, so secret material is never an argument or environment override.
                value = sys.stdin.read().rstrip("\n")
                require(bool(value) and not denied(value), "E_CREDENTIAL")
                driver.vault_set(argv[1], value)
            elif command == "seed":
                from seed import load_seed
                read_fd, write_fd = os.pipe()
                token = os.urandom(32)
                try:
                    os.write(write_fd, token)
                    os.close(write_fd)
                    load_seed(root, env, driver, api, read_fd, token)
                finally: os.close(read_fd)
    finally:
        driver.close()


def main(argv=None):
    try:
        run(sys.argv[1:] if argv is None else argv, os.environ)
        return 0
    except Refused as error:
        print("refused: " + error.code, file=sys.stderr)
    except Exception:
        print("refused: E_OPERATION", file=sys.stderr)
    return 78


if __name__ == "__main__": sys.exit(main())
