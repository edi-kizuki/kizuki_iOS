#!/usr/bin/env python3
"""B03 offline adversarial tests. Related: [[014-b03-environment-pinning]]."""
import contextlib
import copy
from email.message import Message
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

sys.path.insert(0, str(Path(__file__).parent / "remote"))
import kz_guard as guard
import kz_remote as remote
import seed

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / (name + ".py"))
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result


class FakeSQL:
    def __init__(self, snapshot): self.value = copy.deepcopy(snapshot); self.calls = []
    def snapshot(self): self.calls.append("marker"); return copy.deepcopy(self.value)
    def bootstrap(self, content, witness):
        self.calls.append(content.decode()); self.value = staging()
    def migrate(self, files): self.calls.append("migrate")
    def close(self): self.calls.append("close")


def pristine():
    return dict(marker_exists=False, rows=[], user_objects=False, versions=[], fingerprint="2026-10-31 10:00:00+00")


def staging():
    return dict(pristine(), marker_exists=True, user_objects=True, rows=[dict(environment="staging", project_ref=guard.STAGING_REF, api_host=guard.STAGING_API_HOST)])


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(); self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        for relative in ("scripts/remote", "supabase/bootstrap", "supabase/migrations"):
            shutil.copytree(ROOT / relative, self.root / relative, ignore=shutil.ignore_patterns("__pycache__"))
        self.home = self.root / "home"; self.home.mkdir()
        self.bin = self.root / "bin"; self.bin.mkdir()
        self.record = self.root / "calls"
        for name in ("supabase", "psql", "npx", "security"):
            script = self.bin / name
            script.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$KZ_TEST_RECORD"\nexit 99\n'); script.chmod(0o755)
        # Child Python processes share the same zero-socket tripwire via sitecustomize.
        (self.bin / "sitecustomize.py").write_text('import socket\ndef refuse(*a, **k): raise AssertionError("socket forbidden")\nsocket.socket.connect = refuse\nsocket.getaddrinfo = refuse\n')
        self.env = dict(PATH=str(self.bin) + ":" + os.environ["PATH"], HOME=str(self.home),
                        PYTHONPATH=str(self.bin), KZ_TEST_RECORD=str(self.record))
        for target in ("socket.socket.connect", "socket.getaddrinfo"):
            p = patch(target, side_effect=AssertionError("socket forbidden")); p.start(); self.addCleanup(p.stop)
        self.addCleanup(self.assert_no_subprocesses)

    def assert_no_subprocesses(self):
        self.assertFalse(self.record.exists(), self.record.read_text() if self.record.exists() else "")

    def check(self, argv, env=None): return guard.static_checks(argv, self.env | (env or {}), self.root, self.home)

    def refuses(self, code, operation):
        with self.assertRaises(guard.Refused) as caught: operation()
        self.assertEqual(caught.exception.code, code)

    def wrapper(self, args, env=None):
        return subprocess.run(["bash", str(self.root / "scripts/remote/kz-remote.sh"), *args],
                              env=self.env | (env or {}), capture_output=True, text=True)

    def run_fake(self, args, snapshot):
        sql = FakeSQL(snapshot); api = Mock(); api.call.return_value = {}
        credentials = Mock(return_value=("synthetic-db", "sb_secret_synthetic_only"))
        driver = Mock(return_value=sql)
        with contextlib.redirect_stdout(io.StringIO()):
            remote.run(args, self.env, self.root, self.home, driver, lambda _: api, credentials)
        return sql, api, driver, credentials

    def test_G1_flags_and_unknown_subcommands_exit_78(self):
        for arg in ["--" + flag for flag in ("project-ref", "db-url", "linked", "local", "workdir", "password", "experimental")] + ["-p", "link", "--force"]:
            result = self.wrapper(["verify", arg, "value"])
            self.assertEqual(result.returncode, 78); self.assertEqual(result.stderr.strip(), "refused: E_OVERRIDE")
        self.assertEqual(self.wrapper(["unknown"]).returncode, 78)
        self.assertEqual(self.wrapper(["doctor"]).returncode, 0)
        self.assertEqual(list((self.root / "scripts/remote").rglob("*.pyc")), [])

    def test_G2_environment_overrides_including_lowercase_and_empty(self):
        for key in ["SUPABASE_PROJECT_ID", "SUPABASE_DB_URL", "DATABASE_URL", "PGHOST", "PGHOSTADDR", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE", "PGPASSWORD"]:
            for value in ("", "wrong"):
                self.refuses("E_OVERRIDE", lambda: self.check(["verify"], {key.lower(): value}))
        for key in ("HTTP_PROXY", "https_proxy", "ALL_PROXY"):
            self.refuses("E_PROXY", lambda: self.check(["verify"], {key: ""}))
        self.refuses("E_TOKEN_PRESENT", lambda: self.check(["doctor"], {"SUPABASE_ACCESS_TOKEN": ""}))

    def test_G3_link_files_and_pgpass_are_never_deleted(self):
        temp = self.root / "supabase/.temp"; temp.mkdir()
        project = temp / "project-ref"
        for value, code in [(guard.DENIED_REFS[0], "E_REF_DENIED"), ("other", "E_LINK_STATE"), (guard.STAGING_REF, None)]:
            project.write_text(value)
            if code: self.refuses(code, lambda: self.check(["verify"]))
            else: self.check(["verify"])
            self.assertEqual(project.read_text(), value)
        (temp / "pooler-url").write_text("postgresql://postgres@" + guard.DENIED_REFS[0])
        self.refuses("E_REF_DENIED", lambda: self.check(["doctor"]))
        (temp / "pooler-url").unlink()
        (self.home / ".pgpass").write_text(guard.STAGING_POOLER_HOST + ":5432:*:*:" + guard.DENIED_REFS[0])
        self.refuses("E_REF_DENIED", lambda: self.check(["doctor"]))

    def test_G4_pooled_endpoint_matrix(self):
        base = f"postgresql://postgres.{guard.STAGING_REF}@{guard.STAGING_POOLER_HOST}:5432/postgres?sslmode=require"
        guard.validate_dsn(base)
        variants = [base.replace(guard.STAGING_POOLER_HOST, host) for host in ("wrong.test", guard.STAGING_POOLER_HOST + ".evil.test", "127.0.0.1")]
        variants += [base.replace("postgres." + guard.STAGING_REF, user) for user in ("postgres", "postgres." + guard.DENIED_REFS[0])]
        variants += [base.replace(":5432", ":6543"), base.replace("require", "disable"), base + "&host=wrong", base + "&options=bad", base + "&sslmode=require"]
        for value in variants: self.refuses("E_POOLER", lambda: guard.validate_dsn(value))

    def test_G5_redirect_handler_never_opens_followup(self):
        for destination in ["https://" + guard.STAGING_API_HOST, "https://" + guard.DENIED_REFS[0] + ".supabase.co"]:
            handler = remote.NoRedirect(); handler.parent = Mock()
            headers = Message(); headers["Location"] = destination
            request = remote.urllib.request.Request("https://" + guard.STAGING_API_HOST)
            self.refuses("E_REDIRECT", lambda: handler.http_error_302(request, io.BytesIO(), 302, "redirect", headers))
            handler.parent.open.assert_not_called()

    def test_G6_marker_states(self):
        self.assertEqual(guard.state(pristine()), "S0"); self.assertEqual(guard.state(staging()), "S1")
        for changes in [dict(environment="production"), dict(environment="local"), dict(project_ref="other"), dict(api_host="other")]:
            value = staging(); value["rows"][0].update(changes)
            self.refuses("E_MARKER_WRONG", lambda: guard.state(value))
        for rows in ([], staging()["rows"] * 2):
            value = staging(); value["rows"] = rows
            self.refuses("E_MARKER_WRONG", lambda: guard.state(value))
        for changes in [dict(user_objects=True), dict(versions=["1"])]:
            self.refuses("E_NOT_PRISTINE", lambda: guard.state(dict(pristine(), **changes)))
        self.refuses("E_MARKER_ABSENT", lambda: self.run_fake(["migrate"], pristine()))
        sql, _, _, _ = self.run_fake(["migrate"], staging()); self.assertIn("migrate", sql.calls)

    def test_migration_history_must_be_an_ordered_repo_prefix(self):
        versions = [m[0] for m in remote.migrations(self.root)]
        for applied in [["unknown"], versions[1:]]:
            value = staging(); value["versions"] = applied
            self.refuses("E_MIGRATIONS", lambda: self.run_fake(["migrate"], value))

    def test_G7_witness_and_exact_transaction_and_second_bootstrap(self):
        self.refuses("E_WITNESS", lambda: self.run_fake(["bootstrap"], pristine()))
        self.refuses("E_WITNESS", lambda: self.run_fake(["bootstrap", "--witness", "wrong"], pristine()))
        sql, _, _, _ = self.run_fake(["bootstrap", "--witness", pristine()["fingerprint"]], pristine())
        transactions = [call for call in sql.calls if "begin;" in call]
        self.assertEqual(transactions, [(self.root / "supabase/bootstrap/env_marker.sql").read_text()])
        self.assertLess(transactions[0].index("begin;"), transactions[0].index("insert into"))
        self.assertTrue(transactions[0].rstrip().endswith("commit;"))
        self.refuses("E_MARKER_WRONG", lambda: self.run_fake(["bootstrap", "--witness", pristine()["fingerprint"]], staging()))

    def test_G8_edited_file_refused_before_credentials_or_driver(self):
        path = self.root / "supabase/bootstrap/env_marker.sql"; path.write_text(path.read_text() + "\n-- edited")
        result = self.wrapper(["bootstrap", "--witness", "example"])
        self.assertEqual(result.returncode, 78); self.assertIn("E_BOOTSTRAP_FILE", result.stderr)

    def test_G9_empty_production_pin_is_refused_offline(self):
        path = self.root / "scripts/remote/staging.pin"
        path.write_text(path.read_text().replace("api_host=" + guard.STAGING_API_HOST, "api_host=" + guard.DENIED_REFS[0] + ".supabase.co"))
        driver = Mock(); creds = Mock()
        self.refuses("E_POOLER", lambda: remote.run(["bootstrap", "--witness", "x"], self.env, self.root, self.home,
                     driver_factory=driver, credential_source=creds))
        driver.assert_not_called(); creds.assert_not_called()

    def test_G10_dashboard_only_and_G17_no_cli_or_token_store(self):
        for command in ("auth-config", "functions-deploy", "secrets-set"):
            result = self.wrapper([command]); self.assertEqual(result.returncode, 0); self.assertIn("Dashboard checklist", result.stdout)
            result = self.wrapper([command], {"SUPABASE_ACCESS_TOKEN": "synthetic"})
            self.assertEqual(result.returncode, 78); self.assertIn("E_TOKEN_PRESENT", result.stderr)
        # User decision supersedes the design's dummy-token CLI path: no CLI subprocess at all.
        sql, _, _, _ = self.run_fake(["migrate"], staging())
        self.assertIn("migrate", sql.calls); self.assertNotIn("SUPABASE_ACCESS_TOKEN", self.env)

    def test_G11_CI_never_bootstraps(self):
        for key in ("CI", "GITHUB_ACTIONS"):
            result = self.wrapper(["bootstrap", "--witness", "x"], {key: "true"})
            self.assertEqual(result.returncode, 78); self.assertIn("E_CI_BOOTSTRAP", result.stderr)

    def test_G15_seed_prevalidates_entire_dataset(self):
        valid = dict(email="one@seed.kizuki.test", password="synthetic-test-password")
        seed.validate_records([valid])
        self.refuses("E_SEED_EMAIL", lambda: seed.validate_records([valid, dict(email="real@example.com")]))
        self.refuses("E_SEED_HOST", lambda: seed.validate_records([dict(valid, user_metadata={"url": "https://wrong.test/photo"})]))
        folder = self.root / "seed"; folder.mkdir(); (folder / "staging.json").write_text(json.dumps([valid]))
        sql = FakeSQL(staging()); api = Mock()
        read_fd, write_fd = os.pipe()
        try:
            token = b"x" * 32; os.write(write_fd, token); os.close(write_fd)
            seed.load_seed(self.root, self.env, sql, api, read_fd, token)
        finally: os.close(read_fd)
        self.assertEqual(sql.calls[0], "marker"); api.call.assert_called_once()
        result = subprocess.run([sys.executable, str(self.root / "scripts/remote/seed.py")], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 78); self.assertIn("E_NOT_VIA_GATEWAY", result.stderr)


class StaticChecks(unittest.TestCase):
    def test_G12_and_A12_and_E6_repo_and_drift(self):
        pins = module("check-env-pins"); self.assertEqual(pins.check(), [])
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in ("scripts/remote", "ios/Configuration", "supabase/bootstrap", "supabase/migrations", "supabase/functions"):
                shutil.copytree(ROOT / relative, root / relative, ignore=shutil.ignore_patterns("__pycache__", "*.private.xcconfig"))
            target = root / "ios/Packages/KizukiKit/Sources/KizukiCore/BackendAllowlist.swift"
            target.parent.mkdir(parents=True); shutil.copy(ROOT / target.relative_to(root), target)
            target.write_text(target.read_text().replace(guard.STAGING_REF, "other"))
            self.assertTrue(pins.check(root))

    def test_G13_workflow_policy_positive_and_negative(self):
        policy = module("check-workflow-policy"); self.assertEqual(policy.check(), [])
        text = (ROOT / ".github/workflows/foundation.yml").read_text()
        for changed in [text + "\n# " + guard.DENIED_REFS[0], text.replace("runs-on: macos-15", "runs-on: macos-15\n    environment: staging"),
                        text.replace("runs-on: macos-15", "runs-on: macos-15\n    env:\n      " + policy.TOKEN + ": bad"), text.replace(policy.ASSERTION, "true")]:
            self.assertTrue(policy.check_text(changed))

    def test_G14_boundary_repo_and_negative_fixtures(self):
        scanner = module("check-remote-mutations"); self.assertEqual(scanner.check(), [])
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root / ".github/workflows").mkdir(parents=True)
            path = root / ".github/workflows/unsafe.yml"
            for value in ["db" + " push", "functions" + " deploy", "secrets" + " set", "supabase" + " link", "--" + "db-url", "--" + "project-ref", "config" + " push", "api." + "supabase.com", guard.DENIED_REFS[0]]:
                path.write_text(value); self.assertTrue(scanner.check(root))


if __name__ == "__main__": unittest.main()
