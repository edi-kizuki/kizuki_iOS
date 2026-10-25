import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_config", Path(__file__).with_name("validate-release-config.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ReleaseConfigurationTests(unittest.TestCase):
    def settings(self, **changes):
        values = dict(CONFIGURATION="Release", KIZUKI_ENVIRONMENT="production",
                      SUPABASE_URL="https://enosggckdxjiaqtxalhg.supabase.co",
                      SUPABASE_PUBLISHABLE_KEY="sb_publishable_compile_only")
        values.update(changes)
        return values

    def test_valid_public_configuration(self):
        module.validate(self.settings())

    def test_missing_key_blocks_release(self):
        with self.assertRaises(ValueError): module.validate(self.settings(SUPABASE_PUBLISHABLE_KEY=""))

    def test_staging_cannot_target_production(self):
        with self.assertRaises(ValueError): module.validate(self.settings(CONFIGURATION="Staging", KIZUKI_ENVIRONMENT="staging"))

    def test_wrong_scheme_environment_and_secret_fail(self):
        for change in [dict(KIZUKI_ENVIRONMENT="local"), dict(SUPABASE_PUBLISHABLE_KEY="sb_secret_unsafe"),
                       dict(SUPABASE_URL="http://localhost:54321"), dict(SUPABASE_URL="https://enosggckdxjiaqtxalhg.supabase.co.evil.test")]:
            with self.subTest(change=change), self.assertRaises(ValueError): module.validate(self.settings(**change))

if __name__ == "__main__": unittest.main()
