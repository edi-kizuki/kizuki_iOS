from remote.kz_guard import DENIED_REFS
import unittest
from local_backend import require_local_url

class LocalGuardTests(unittest.TestCase):
    def test_accepts_only_local_stack(self):
        self.assertEqual(require_local_url("http://127.0.0.1:54321/"), "http://127.0.0.1:54321")
        self.assertEqual(require_local_url("http://localhost:54321"), "http://localhost:54321")

    def test_refuses_production_and_lookalikes(self):
        for value in ["https://" + DENIED_REFS[0] + ".supabase.co", "https://staging.supabase.co",
                      "http://localhost.evil.test:54321", "http://127.0.0.1:54321/path",
                      "http://localhost:54321?redirect=evil", "http://user@localhost:54321",
                      "http://localhost:54322", "file:///tmp/local", "http://localhost:54321#fragment"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                require_local_url(value)

if __name__ == "__main__":
    unittest.main()
