import importlib.util
import plistlib
import tempfile
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_config", Path(__file__).with_name("validate-release-config.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

artifact_spec = importlib.util.spec_from_file_location("release_artifact", Path(__file__).with_name("check-release-artifact.py"))
artifact = importlib.util.module_from_spec(artifact_spec)
artifact_spec.loader.exec_module(artifact)

class ReleaseArtifactTests(unittest.TestCase):
    def make_app(self, scratch, executable=b"clean binary", **plist):
        app = Path(scratch) / "Kizuki.app"
        app.mkdir()
        info = dict(CFBundleIdentifier="club.kizuki.ios", KizukiEnvironment="staging",
                    SupabaseURL="https://ankgfqkgflcalmlreetu.supabase.co",
                    SupabasePublishableKey="sb_publishable_ci_compile_only")
        info.update(plist)
        (app / "Info.plist").write_bytes(plistlib.dumps(info))
        (app / "Kizuki").write_bytes(executable)
        return app

    def test_clean_artifact_passes(self):
        with tempfile.TemporaryDirectory() as scratch:
            self.assertEqual(artifact.inspect_app(self.make_app(scratch), "staging"), [])

    def test_fixture_symbols_and_prototype_strings_fail(self):
        for payload in [b"..FixtureBackend..", b"$s10KizukiTestSupport", b"UITestBackend", b"PrototypeRoot", b"--ui-testing",
                        b"mika@example.com", b"Prototype: any email works. Nothing is sent.", b"Your account was deleted"]:
            with self.subTest(payload=payload), tempfile.TemporaryDirectory() as scratch:
                self.assertTrue(artifact.inspect_app(self.make_app(scratch, executable=b"x" + payload + b"y"), "staging"))

    def test_identity_environment_and_debug_artifacts_fail(self):
        for changes in [dict(CFBundleIdentifier="club.kizuki.ios.staging"), dict(KizukiEnvironment="local"),
                        dict(SupabaseURL="https://otherprojectref.supabase.co"), dict(SupabasePublishableKey="sb_secret_nope")]:
            with self.subTest(changes=changes), tempfile.TemporaryDirectory() as scratch:
                self.assertTrue(artifact.inspect_app(self.make_app(scratch, **changes), "staging"))
        with tempfile.TemporaryDirectory() as scratch:
            app = self.make_app(scratch)
            (app / "Kizuki.debug.dylib").write_bytes(b"x")
            self.assertTrue(artifact.inspect_app(app, "staging"))

class ReleaseConfigurationTests(unittest.TestCase):
    def settings(self, **changes):
        values = dict(CONFIGURATION="Release", KIZUKI_ENVIRONMENT="production",
                      SUPABASE_URL="https://enosggckdxjiaqtxalhg.supabase.co",
                      SUPABASE_PUBLISHABLE_KEY="sb_publishable_compile_only",
                      PRODUCT_BUNDLE_IDENTIFIER="club.kizuki.ios")
        values.update(changes)
        return values

    def test_production_is_refused_even_with_valid_public_configuration(self):
        with self.assertRaisesRegex(ValueError, "Production configuration is disabled in v0"):
            module.validate(self.settings())

    def test_missing_key_blocks_release(self):
        with self.assertRaises(ValueError): module.validate(self.settings(SUPABASE_PUBLISHABLE_KEY=""))

    def test_staging_cannot_target_production(self):
        with self.assertRaises(ValueError): module.validate(self.settings(CONFIGURATION="Staging", KIZUKI_ENVIRONMENT="staging"))

    def staging(self, **changes):
        values = dict(CONFIGURATION="Staging", KIZUKI_ENVIRONMENT="staging",
                      SUPABASE_URL="https://ankgfqkgflcalmlreetu.supabase.co")
        values.update(changes)
        return self.settings(**values)

    def test_approved_staging_project_is_accepted(self):
        module.validate(self.staging())

    def test_staging_rejects_every_other_host(self):
        for url in ["https://otherprojectref.supabase.co", "https://ankgfqkgflcalmlreetu.supabase.co.evil.test",
                    "https://xankgfqkgflcalmlreetu.supabase.co", "http://ankgfqkgflcalmlreetu.supabase.co",
                    "https://ankgfqkgflcalmlreetu.supabase.co:8443", ""]:
            with self.subTest(url=url), self.assertRaises(ValueError): module.validate(self.staging(SUPABASE_URL=url))

    def test_one_app_identity_for_staging_and_production(self):
        module.validate(self.staging(PRODUCT_BUNDLE_IDENTIFIER="club.kizuki.ios"))
        for bundle in ["club.kizuki.ios.staging", "club.kizuki.ios.local", ""]:
            with self.subTest(bundle=bundle):
                with self.assertRaises(ValueError): module.validate(self.staging(PRODUCT_BUNDLE_IDENTIFIER=bundle))
                with self.assertRaises(ValueError): module.validate(self.settings(PRODUCT_BUNDLE_IDENTIFIER=bundle))

    def test_wrong_scheme_environment_and_secret_fail(self):
        for change in [dict(KIZUKI_ENVIRONMENT="local"), dict(SUPABASE_PUBLISHABLE_KEY="sb_secret_unsafe"),
                       dict(SUPABASE_URL="http://localhost:54321"), dict(SUPABASE_URL="https://enosggckdxjiaqtxalhg.supabase.co.evil.test")]:
            with self.subTest(change=change), self.assertRaises(ValueError): module.validate(self.settings(**change))

if __name__ == "__main__": unittest.main()
