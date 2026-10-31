"""Guarded seed boundary; B20 owns the dataset. Related: [[031-b20-staging-deploy-seed]]."""
import hmac
import json
import os
import sys
from urllib.parse import urlsplit
sys.dont_write_bytecode = True

from kz_guard import Refused, require, state, static_checks, STAGING_API_HOST, denied


def validate_records(records):
    require(isinstance(records, list), "E_SEED")
    for record in records:
        require(isinstance(record, dict) and set(record) <= {"email", "password", "email_confirm", "user_metadata"}, "E_SEED")
        email = record.get("email", "")
        require(isinstance(email, str) and email.endswith("@seed.kizuki.test") and email.count("@") == 1
                and email.isascii() and not any(c.isspace() for c in email), "E_SEED_EMAIL")
        def visit(value):
            if isinstance(value, dict):
                for item in value.values(): visit(item)
            elif isinstance(value, list):
                for item in value: visit(item)
            elif isinstance(value, str):
                require(not denied(value), "E_REF_DENIED")
                if "://" in value:
                    p = urlsplit(value)
                    require(p.scheme == "https" and p.netloc == STAGING_API_HOST, "E_SEED_HOST")
        visit(record)


def load_seed(root, env, driver, api, fd, token):
    require(len(token) == 32 and hmac.compare_digest(os.read(fd, 32), token), "E_NOT_VIA_GATEWAY")
    static_checks(["seed"], env, root)
    require(state(driver.snapshot()) == "S1", "E_MARKER_ABSENT")
    path = root / "seed/staging.json"
    require(path.is_file(), "E_SEED_PENDING")
    records = json.loads(path.read_text())
    validate_records(records)  # Entire dataset before the first write.
    for record in records: api.call("/auth/v1/admin/users", record)


if __name__ == "__main__":
    print("refused: E_NOT_VIA_GATEWAY", file=sys.stderr)
    sys.exit(78)
