#!/usr/bin/env python3
"""Reject a real Debug fixture binary with only system tools on PATH. No rg/nm dependency."""
import os
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

app = Path(sys.argv[1])
images = [app / 'Kizuki', *app.glob('*.dylib')]
payload = next((p.read_bytes() for p in images if p.is_file() and b'FixtureBackend' in p.read_bytes()), None)
if payload is None:
    raise SystemExit('error: negative control requires a real Debug binary containing FixtureBackend')
with tempfile.TemporaryDirectory() as scratch:
    control = Path(scratch) / 'Kizuki.app'
    control.mkdir()
    (control / 'Kizuki').write_bytes(payload)
    (control / 'Info.plist').write_bytes(plistlib.dumps(dict(
        CFBundleIdentifier='club.kizuki.ios', CFBundleExecutable='Kizuki', KizukiEnvironment='staging',
        SupabaseURL='https://ankgfqkgflcalmlreetu.supabase.co', SupabasePublishableKey='sb_publishable_compile_only')))
    result = subprocess.run([sys.executable, str(Path(__file__).with_name('check-release-artifact.py')),
                             str(control), 'staging'], capture_output=True, text=True,
                            env=dict(os.environ, PATH='/usr/bin:/bin:/usr/sbin:/sbin'))
    if result.returncode != 1 or 'forbidden symbol in Kizuki: FixtureBackend' not in result.stderr:
        raise SystemExit('error: fixture binary was not rejected by the artifact checker')
    print('ok: real Debug fixture binary rejected (exit 1) with minimal system PATH')
