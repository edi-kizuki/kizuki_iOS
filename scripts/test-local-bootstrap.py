#!/usr/bin/env python3
"""E5 runs the actual bootstrap SQL in rollback-only local pgTAP tests.
Related: [[014-b03-environment-pinning]]. No host DSN or credentials accepted.
"""
from pathlib import Path
import hashlib
import re
import subprocess
from remote.kz_guard import BOOTSTRAP_SHA256

root = Path(__file__).resolve().parents[1]
content = (root / "supabase/bootstrap/env_marker.sql").read_bytes()
assert hashlib.sha256(content).hexdigest() == BOOTSTRAP_SHA256
# pgTAP's exception subtransaction owns the boundary; execute the byte-identical body.
body = re.sub(r'^begin;\s*', '', content.decode(), count=1, flags=re.M)
body = re.sub(r'commit;\s*$', '', body, count=1)
sql = """begin;
create extension if not exists pgtap with schema extensions;
select plan(3);
select throws_ok($b03$BODY$b03$, 'P0001', 'already_bootstrapped', 'E5 actual file refuses second run');
select is((select count(*) from kizuki_env.environment_marker), 1::bigint, 'E5 row unchanged');
drop schema kizuki_env cascade;
create table public.b03_pristine_probe(id int);
select throws_ok($b03$BODY$b03$, 'P0001', 'not_pristine', 'E5 actual file refuses non-pristine database');
select * from finish();
rollback;
""".replace('BODY', body)
result = subprocess.run(['docker', 'exec', '-i', 'supabase_db_kizuki-local', 'psql', '-X', '-U', 'postgres', '-d', 'postgres',
                         '-v', 'ON_ERROR_STOP=1', '-At'], input=sql, text=True, capture_output=True)
if result.returncode or 'not ok' in result.stdout or '# Looks like' in result.stdout:
    print(result.stdout); print(result.stderr); raise SystemExit(1)
print('E5: actual bootstrap file refused double-run and non-pristine local database (3 pgTAP checks).')
