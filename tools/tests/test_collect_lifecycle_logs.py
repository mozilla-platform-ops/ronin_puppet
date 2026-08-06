import datetime
import importlib.machinery
import importlib.util
import io
import pathlib
import tarfile
import tempfile
import unittest


COLLECTOR_PATH = pathlib.Path(__file__).parents[1] / "collect-lifecycle-logs.py"
LOADER = importlib.machinery.SourceFileLoader("collect_lifecycle_logs", str(COLLECTOR_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
collector = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(collector)


class CollectionTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tempdir.name)

    def tearDown(self):
        self.tempdir.cleanup()

    def test_snapshot_is_timestamped_and_never_overwritten(self):
        timestamp = datetime.datetime(2026, 8, 6, 2, 0, tzinfo=datetime.timezone.utc)
        destination = collector.create_snapshot(self.root, timestamp)
        self.assertEqual(destination.name, "20260806T020000Z")
        with self.assertRaises(FileExistsError):
            collector.create_snapshot(self.root, timestamp)

    def test_host_validation_allows_fqdns_and_rejects_paths(self):
        self.assertEqual(
            collector.validate_host("t-linux64-ms-015.test.releng.mdc1.mozilla.com"),
            "t-linux64-ms-015.test.releng.mdc1.mozilla.com",
        )
        with self.assertRaises(ValueError):
            collector.validate_host("host/../../other")

    def test_safe_extract_preserves_active_and_rotated_logs(self):
        archive_path = self.root / "events.tar.gz"
        destination = self.root / "host"
        destination.mkdir()
        with tarfile.open(archive_path, "w:gz") as archive:
            for name, content in (("./events.jsonl", b"active\n"), ("./events.jsonl.1.gz", b"rotated")):
                member = tarfile.TarInfo(name)
                member.size = len(content)
                archive.addfile(member, io.BytesIO(content))

        collector.safe_extract(archive_path, destination)
        self.assertEqual((destination / "events.jsonl").read_bytes(), b"active\n")
        self.assertEqual((destination / "events.jsonl.1.gz").read_bytes(), b"rotated")

    def test_safe_extract_rejects_unexpected_archive_members(self):
        archive_path = self.root / "unsafe.tar.gz"
        destination = self.root / "host"
        destination.mkdir()
        with tarfile.open(archive_path, "w:gz") as archive:
            member = tarfile.TarInfo("./not-events.txt")
            member.size = 1
            archive.addfile(member, io.BytesIO(b"x"))

        with self.assertRaises(collector.CollectionError):
            collector.safe_extract(archive_path, destination)


if __name__ == "__main__":
    unittest.main()
