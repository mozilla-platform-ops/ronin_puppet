import datetime
import contextlib
import importlib.machinery
import importlib.util
import io
import pathlib
import tarfile
import tempfile
import unittest
from unittest import mock
from types import SimpleNamespace


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

    def archive_bytes(self, name="events.jsonl", content=b"active\n"):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w:gz") as archive:
            member = tarfile.TarInfo(name)
            member.size = len(content)
            archive.addfile(member, io.BytesIO(content))
        return output.getvalue()

    def test_hostile_errors_are_escaped_and_next_host_is_collected(self):
        controls = "".join(chr(code) for code in list(range(32)) + list(range(127, 160)))
        payload = "remote\x1b]52;c;clipboard\x07" + controls + "\u202eend"
        good_archive = self.archive_bytes()
        for failure in ("ssh", "archive_name", "nested_error"):
            with self.subTest(failure=failure):
                calls = []

                def ssh(command, stdout, **_kwargs):
                    host = command[1]
                    calls.append(host)
                    if host == "bad-host" and failure == "ssh":
                        return SimpleNamespace(returncode=1, stderr=payload)
                    data = self.archive_bytes("events.jsonl" + payload) if host == "bad-host" and failure == "archive_name" else good_archive
                    stdout.write(data)
                    return SimpleNamespace(returncode=0, stderr="")

                extract = collector.safe_extract

                def extract_with_error(archive, destination):
                    if destination.name == "bad-host" and failure == "nested_error":
                        raise OSError(payload)
                    return extract(archive, destination)

                out, err = io.StringIO(), io.StringIO()
                with mock.patch.object(collector.subprocess, "run", side_effect=ssh), \
                     mock.patch.object(collector, "safe_extract", side_effect=extract_with_error), \
                     contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                    status = collector.main(["--output-directory", str(self.root / failure), "bad-host", "good-host"])
                self.assertEqual(status, 1)
                self.assertEqual(calls, ["bad-host", "good-host"])
                self.assertIn("collected good-host", out.getvalue())
                self.assertEqual(len(err.getvalue().splitlines()), 1)
                self.assertIn(r"\x1b]52;c;clipboard\x07", err.getvalue())
                self.assertIn(r"\u202e", err.getvalue())
                self.assertTrue(all(character.isprintable() or character == "\n" for character in out.getvalue() + err.getvalue()))
                logs = list((self.root / failure).glob("*/good-host/events.jsonl"))
                self.assertEqual(len(logs), 1)
                self.assertEqual(logs[0].read_bytes(), b"active\n")
                self.assertEqual(list((self.root / failure).rglob(".events.tar.gz")), [])

    def test_archive_path_and_type_protections_are_preserved(self):
        for index, (name, member_type) in enumerate((
            ("../events.jsonl", tarfile.REGTYPE),
            ("/events.jsonl", tarfile.REGTYPE),
            ("./events.jsonl", tarfile.SYMTYPE),
            ("./events.jsonl", tarfile.LNKTYPE),
            ("./events.jsonl", tarfile.DIRTYPE),
        )):
            with self.subTest(name=name, member_type=member_type):
                archive_path = self.root / "unsafe.tar.gz"
                destination = self.root / str(index)
                destination.mkdir()
                with tarfile.open(archive_path, "w:gz") as archive:
                    member = tarfile.TarInfo(name)
                    member.type = member_type
                    member.linkname = "../outside"
                    archive.addfile(member)
                with self.assertRaises(collector.CollectionError):
                    collector.safe_extract(archive_path, destination)
                self.assertEqual(list(destination.iterdir()), [])
                self.assertFalse((self.root / "events.jsonl").exists())

    def test_active_log_is_required(self):
        archive_path = self.root / "rotated-only.tar.gz"
        archive_path.write_bytes(self.archive_bytes("events.jsonl.1"))
        destination = self.root / "host"
        destination.mkdir()
        with self.assertRaisesRegex(collector.CollectionError, "did not contain events.jsonl"):
            collector.safe_extract(archive_path, destination)

    def test_success_destination_is_escaped_without_changing_files(self):
        destination = self.root / "snapshot\x1b[2K\r\n\u200b"
        out = io.StringIO()
        with mock.patch.object(collector.subprocess, "run") as ssh, contextlib.redirect_stdout(out):
            def write_archive(_command, stdout, **_kwargs):
                stdout.write(self.archive_bytes())
                return SimpleNamespace(returncode=0, stderr="")
            ssh.side_effect = write_archive
            status = collector.main(["--output-directory", str(destination), "good-host"])
        self.assertEqual(status, 0)
        self.assertEqual(len(out.getvalue().splitlines()), 1)
        self.assertIn(r"snapshot\x1b[2K\r\n\u200b", out.getvalue())
        self.assertEqual(len(list(destination.glob("*/good-host/events.jsonl"))), 1)


if __name__ == "__main__":
    unittest.main()
