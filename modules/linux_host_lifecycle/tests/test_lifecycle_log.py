import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest import mock


LOGGER_PATH = pathlib.Path(__file__).parents[1] / "files" / "lifecycle-log"
LOADER = importlib.machinery.SourceFileLoader("lifecycle_log", str(LOGGER_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
lifecycle_log = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(lifecycle_log)


class LifecycleLogTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.log_path = pathlib.Path(self.tempdir.name) / "events.jsonl"

    def tearDown(self):
        self.tempdir.cleanup()

    def read_events(self):
        return [json.loads(line) for line in self.log_path.read_text().splitlines()]

    @mock.patch.object(lifecycle_log, "read_boot_id", return_value="boot-123")
    @mock.patch.object(lifecycle_log.socket, "gethostname", return_value="test-host")
    def test_emit_appends_complete_records(self, _hostname, _boot_id):
        lifecycle_log.emit("worker_started", log_path=str(self.log_path))
        lifecycle_log.emit("worker_exited", exit_code=7, log_path=str(self.log_path))

        events = self.read_events()
        self.assertEqual([event["event"] for event in events], ["worker_started", "worker_exited"])
        self.assertEqual(events[0]["host_id"], "test-host")
        self.assertEqual(events[0]["boot_id"], "boot-123")
        self.assertEqual(events[1]["exit_code"], 7)
        self.assertTrue(all(event["event_id"] for event in events))

    @mock.patch.object(lifecycle_log.socket, "gethostname", return_value="test-host")
    def test_observe_boot_is_idempotent(self, _hostname):
        self.assertTrue(lifecycle_log.observe_boot(str(self.log_path), "boot-123", 1_725_000_000))
        self.assertFalse(lifecycle_log.observe_boot(str(self.log_path), "boot-123", 1_725_000_000))

        events = self.read_events()
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["event"], "boot_started")
        self.assertEqual(events[0]["boot_id"], "boot-123")
        self.assertEqual(events[0]["event_time"], "2024-08-30T06:40:00.000Z")

    def test_invalid_partial_line_does_not_block_boot_observation(self):
        self.log_path.write_text('{"event":"boot_started"\n')

        self.assertTrue(lifecycle_log.observe_boot(str(self.log_path), "boot-123", 1_725_000_000))
        valid_events = []
        for line in self.log_path.read_text().splitlines():
            try:
                valid_events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        self.assertEqual(len(valid_events), 1)


if __name__ == "__main__":
    unittest.main()
