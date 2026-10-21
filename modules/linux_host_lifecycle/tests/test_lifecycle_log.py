import importlib.machinery
import importlib.util
import json
import os
import pathlib
import stat
import tempfile
import unittest
from unittest import mock
import gzip


LOGGER_PATH = pathlib.Path(__file__).parents[1] / "files" / "lifecycle-log"
LOADER = importlib.machinery.SourceFileLoader("lifecycle_log", str(LOGGER_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
lifecycle_log = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(lifecycle_log)


class LifecycleLogTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.log_path = pathlib.Path(self.tempdir.name) / "events.jsonl"
        self.log_path.touch(mode=0o664)
        self.log_path.chmod(0o664)
        # Run on developer machines without chown/root. Keep the real file type,
        # mode, inode, and link count while simulating Puppet-managed ownership.
        self.real_fstat = os.fstat
        self.root_stat = mock.patch.object(lifecycle_log.os, "fstat", side_effect=self.root_owned_stat)
        self.root_stat.start()
        self.addCleanup(self.root_stat.stop)

    def root_owned_stat(self, descriptor):
        fields = list(self.real_fstat(descriptor))
        fields[4] = 0
        return os.stat_result(fields)

    def tearDown(self):
        self.tempdir.cleanup()

    def read_events(self):
        return [json.loads(line) for line in self.log_path.read_text().splitlines()]

    @staticmethod
    def metric_line(metric):
        return "Aug  5 06:41:02 test-host generic-worker: WORKER_METRICS {}\n".format(
            json.dumps(metric)
        )

    def log_operations(self):
        return (
            lambda: lifecycle_log.append_event({"event": "worker_started"}, str(self.log_path)),
            lambda: lifecycle_log.observe_boot(str(self.log_path), "boot-123", 1_725_000_000),
            lambda: list(lifecycle_log.read_events(str(self.log_path))),
        )

    def assert_log_rejected(self):
        for operation in self.log_operations():
            with self.subTest(operation=operation):
                with self.assertRaises((OSError, ValueError)):
                    operation()

    def test_symlink_target_is_never_read_or_modified(self):
        target = pathlib.Path(self.tempdir.name) / "root-file"
        target.write_text('sensitive root file\n')
        self.log_path.unlink()
        self.log_path.symlink_to(target)
        self.assert_log_rejected()
        self.assertEqual(target.read_text(), 'sensitive root file\n')

    def test_hard_link_target_is_never_modified(self):
        target = pathlib.Path(self.tempdir.name) / "root-file"
        target.write_text('sensitive root file\n')
        self.log_path.unlink()
        os.link(target, self.log_path)
        self.assert_log_rejected()
        self.assertEqual(target.read_text(), 'sensitive root file\n')

    def test_fifo_is_rejected_without_waiting_for_a_writer(self):
        self.log_path.unlink()
        os.mkfifo(self.log_path)
        self.assert_log_rejected()

    def test_directory_target_is_rejected(self):
        self.log_path.unlink()
        self.log_path.mkdir()
        self.assert_log_rejected()

    def test_writable_parent_directory_is_rejected(self):
        os.chmod(self.tempdir.name, 0o775)
        self.assert_log_rejected()
        self.assertEqual(self.log_path.read_text(), '')

    def test_symlink_parent_directory_is_rejected(self):
        parent_link = pathlib.Path(self.tempdir.name) / "parent-link"
        parent_link.symlink_to(self.tempdir.name, target_is_directory=True)
        self.log_path = parent_link / "events.jsonl"
        self.assert_log_rejected()

    def test_non_root_file_or_directory_is_rejected(self):
        for file_type in (stat.S_ISREG, stat.S_ISDIR):
            def untrusted_stat(descriptor):
                fields = list(self.root_owned_stat(descriptor))
                if file_type(fields[0]):
                    fields[4] = 1000
                return os.stat_result(fields)

            with self.subTest(file_type=file_type):
                with mock.patch.object(lifecycle_log.os, "fstat", side_effect=untrusted_stat):
                    self.assert_log_rejected()

    def test_world_writable_file_is_rejected(self):
        self.log_path.chmod(0o666)
        self.assert_log_rejected()

    def test_missing_log_is_not_created_by_emitter(self):
        self.log_path.unlink()
        with self.assertRaises(FileNotFoundError):
            lifecycle_log.append_event({"event": "worker_started"}, str(self.log_path))
        self.assertFalse(self.log_path.exists())

    def test_logging_resumes_after_rotation_recreates_file(self):
        lifecycle_log.append_event({"event": "worker_started"}, str(self.log_path))
        rotated = self.log_path.with_suffix('.jsonl.1')
        self.log_path.rename(rotated)
        self.log_path.touch()
        self.log_path.chmod(0o664)
        lifecycle_log.append_event({"event": "worker_exited"}, str(self.log_path))
        self.assertEqual(self.read_events(), [{"event": "worker_exited"}])
        self.assertEqual(json.loads(rotated.read_text()), {"event": "worker_started"})

    def test_importer_rejects_swap_between_read_and_append(self):
        boot_time = 1_725_000_000
        lifecycle_log.observe_boot(str(self.log_path), "boot-123", boot_time)
        target = pathlib.Path(self.tempdir.name) / "root-file"
        target.write_text('sensitive root file\n')

        def swap_log(_path):
            self.log_path.unlink()
            self.log_path.symlink_to(target)
            yield {
                "eventType": "workerReady", "timestamp": boot_time + 10,
                "workerId": "test-host", "workerPoolId": "releng-hardware/test",
            }

        with mock.patch.object(lifecycle_log, "metrics_from_log", side_effect=swap_log):
            with self.assertRaises(OSError):
                lifecycle_log.import_generic_worker(
                    str(self.log_path), "unused-syslog", "boot-123", boot_time + 60
                )
        self.assertEqual(target.read_text(), 'sensitive root file\n')

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

    def test_corrupt_encoding_does_not_block_boot_observation_or_import(self):
        # Bytes beginning with three NULs look like UTF-32-BE to json.loads.
        # A truncated/corrupt record must not prevent subsequent valid events.
        broken_utf32 = b'\x00\x00\x00{' + b'\x00\x00\x00 ' * 132 + b'\x00\x00\x00'
        with self.assertRaises(UnicodeDecodeError):
            json.loads(broken_utf32)
        corrupt = broken_utf32 + b'\n\xff\xfe invalid UTF-8\n'
        self.log_path.write_bytes(corrupt)
        self.assertTrue(lifecycle_log.observe_boot(str(self.log_path), 'boot-123', 1_725_000_000))
        self.assertFalse(lifecycle_log.observe_boot(str(self.log_path), 'boot-123', 1_725_000_000))
        self.assertEqual(lifecycle_log.current_boot_started(str(self.log_path), 'boot-123'), 1_725_000_000)
        events = list(lifecycle_log.read_events(str(self.log_path)))
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]['event'], 'boot_started')
        metric = {
            'eventType': 'workerReady', 'timestamp': 1_725_000_010,
            'workerId': 'test-host', 'workerPoolId': 'releng-hardware/test',
        }
        with mock.patch.object(lifecycle_log, 'metrics_from_log', return_value=iter([metric])):
            imported = lifecycle_log.import_generic_worker(
                str(self.log_path), str(self.log_path.parent / 'unused-syslog'),
                'boot-123', 1_725_000_060,
            )
        self.assertEqual(imported, 1)
        self.assertEqual([event['event'] for event in lifecycle_log.read_events(str(self.log_path))],
                         ['boot_started', 'worker_ready'])
        self.assertTrue(self.log_path.read_bytes().startswith(corrupt))

    def test_non_object_json_records_are_ignored(self):
        self.log_path.write_text('null\n[]\n42\n"string"\n')
        self.assertTrue(lifecycle_log.observe_boot(str(self.log_path), 'boot-123', 1_725_000_000))
        self.assertFalse(lifecycle_log.observe_boot(str(self.log_path), 'boot-123', 1_725_000_000))
        events = list(lifecycle_log.read_events(str(self.log_path)))
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]['boot_id'], 'boot-123')

    @mock.patch.object(lifecycle_log.socket, "gethostname", return_value="test-host")
    def test_importer_filters_deduplicates_and_reads_rotations(self, _hostname):
        boot_time = 1_725_000_000
        boot_id = "boot-123"
        syslog_path = pathlib.Path(self.tempdir.name) / "syslog"
        rotation_path = pathlib.Path(self.tempdir.name) / "syslog.1"
        compressed_rotation_path = pathlib.Path(self.tempdir.name) / "syslog.2.gz"
        worker_fields = {
            "worker": "generic-worker",
            "workerId": "test-host",
            "workerPoolId": "releng-hardware/test",
            "instanceType": "",
            "region": "",
        }
        ready = {"eventType": "workerReady", "timestamp": boot_time + 10, **worker_fields}
        started = {
            "eventType": "taskStart",
            "timestamp": boot_time + 20,
            "taskId": "task-1",
            "runId": 0,
            **worker_fields,
        }
        finished = {
            "eventType": "taskFinish",
            "timestamp": boot_time + 30,
            "taskId": "task-1",
            "runId": 0,
            **worker_fields,
        }
        old_metric = {"eventType": "workerReady", "timestamp": boot_time - 1, **worker_fields}

        lifecycle_log.observe_boot(str(self.log_path), boot_id, boot_time)
        syslog_path.write_text(self.metric_line(ready) + self.metric_line(old_metric))
        rotation_path.write_text(self.metric_line(started))
        with gzip.open(compressed_rotation_path, "wt", encoding="utf-8") as compressed_log:
            compressed_log.write(self.metric_line(finished))

        imported = lifecycle_log.import_generic_worker(
            str(self.log_path), str(syslog_path), boot_id, boot_time + 60
        )
        self.assertEqual(imported, 3)
        events = self.read_events()
        imported_events = [event for event in events if event["source"] == "generic-worker-log"]
        self.assertEqual(
            [event["event"] for event in imported_events],
            ["worker_ready", "task_started", "task_finished"],
        )
        self.assertEqual(imported_events[1]["task_id"], "task-1")
        self.assertEqual(imported_events[1]["run_id"], 0)
        self.assertEqual(imported_events[0]["event_time"], "2024-08-30T06:40:10.000Z")
        self.assertEqual(len({event["source_record_id"] for event in imported_events}), 3)

        self.assertEqual(
            lifecycle_log.import_generic_worker(
                str(self.log_path), str(syslog_path), boot_id, boot_time + 60
            ),
            0,
        )
        self.assertEqual(len(self.read_events()), 4)


if __name__ == "__main__":
    unittest.main()
