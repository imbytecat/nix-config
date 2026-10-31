import tempfile
import unittest
from pathlib import Path

from update import update_hash


OLD_HASH = "sha256-K2jqjjtaxd41CtW2dhMjcDHoJmeMptGqc9Jp2RtMCxI="
NEW_HASH = "sha256-40UAq0RibcA5oGQXkuy6mKtjMHZG6z0pGGvlZgj/4JQ="
SOURCE = '{\n  url = "https://example.invalid/model.gram";\n  hash = "' + OLD_HASH + '";\n}\n'
ASSET = {
    "name": "wanxiang-lts-zh-hans.gram",
    "state": "uploaded",
    "size": 418078764,
    "digest": "sha256:e34500ab44626dc039a0641792ecba98ab63307646eb3d29186be56608ffe094",
}


class UpdateHashTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.package = Path(directory.name) / "default.nix"
        self.package.write_text(SOURCE, encoding="utf-8")

    def test_updates_selected_asset_and_leaves_identical_hash_untouched(self):
        release = {"assets": [{"name": "wanxiang-lts-zh-hant.gram"}, ASSET]}
        update_hash(self.package, release)
        self.assertEqual(
            self.package.read_text(encoding="utf-8"), SOURCE.replace(OLD_HASH, NEW_HASH)
        )
        before = self.package.stat()
        update_hash(self.package, release)
        after = self.package.stat()
        self.assertEqual(
            (after.st_ino, after.st_mtime_ns), (before.st_ino, before.st_mtime_ns)
        )

    def test_invalid_metadata_never_changes_package(self):
        cases = [
            [],
            [{"name": "other.gram"}],
            [ASSET, ASSET],
            [dict(ASSET, state="new")],
            [dict(ASSET, size=0)],
            [dict(ASSET, digest=None)],
            [dict(ASSET, digest="sha256:bad")],
            [dict(ASSET, digest="sha512:" + "0" * 64)],
        ]
        for assets in cases:
            with self.subTest(assets=assets):
                with self.assertRaises(ValueError):
                    update_hash(self.package, {"assets": assets})
                self.assertEqual(self.package.read_text(encoding="utf-8"), SOURCE)

    def test_missing_or_ambiguous_source_hash_never_changes_package(self):
        for source in ("{}\n", SOURCE + SOURCE):
            with self.subTest(source=source):
                self.package.write_text(source, encoding="utf-8")
                with self.assertRaises(ValueError):
                    update_hash(self.package, {"assets": [ASSET]})
                self.assertEqual(self.package.read_text(encoding="utf-8"), source)


if __name__ == "__main__":
    unittest.main()
