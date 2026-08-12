import datetime
import gzip
import importlib.machinery
import importlib.util
import json
import pathlib
import tempfile
import unittest


ANALYZER_PATH = pathlib.Path(__file__).parents[1] / "analyze-lifecycle-logs.py"
LOADER = importlib.machinery.SourceFileLoader("analyze_lifecycle_logs", str(ANALYZER_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
analyzer = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(analyzer)


def timestamp(seconds):
    return datetime.datetime.fromtimestamp(seconds, datetime.timezone.utc).isoformat().replace("+00:00", "Z")


def event(name, seconds, boot_id, event_id, **fields):
    record = {
        "event": name,
        "event_time": timestamp(seconds),
        "recorded_at": timestamp(seconds),
        "host_id": "host-a",
        "boot_id": boot_id,
        "event_id": event_id,
    }
    record.update(fields)
    return record


class AnalyzerTests(unittest.TestCase):
    def test_nearest_rank(self):
        self.assertEqual(analyzer.nearest_rank([1, 2, 3, 4], 0.50), 2)
        self.assertEqual(analyzer.nearest_rank([1, 2, 3, 4], 0.95), 4)

    def test_aggregation_calculates_documented_intervals(self):
        events = [
            event("boot_started", 0, "boot-a", "1"),
            event("puppet_run_started", 10, "boot-a", "2"),
            event("puppet_run_succeeded", 40, "boot-a", "3"),
            event("worker_started", 50, "boot-a", "4"),
            event("worker_ready", 60, "boot-a", "5"),
            event("task_started", 70, "boot-a", "6", task_id="task", run_id=0),
            event("task_finished", 100, "boot-a", "7", task_id="task", run_id=0),
            event("restart_executed", 110, "boot-a", "8"),
            event("boot_started", 200, "boot-b", "9"),
            event("worker_started", 220, "boot-b", "10"),
        ]
        samples, incomplete = analyzer.aggregate(events)
        self.assertEqual(samples["early_host_startup"][0]["seconds"], 10)
        self.assertEqual(samples["puppet_run"][0]["seconds"], 30)
        self.assertEqual(samples["worker_initialization"][0]["seconds"], 10)
        self.assertEqual(samples["task_runtime"][0]["seconds"], 30)
        self.assertEqual(samples["post_task_overhead"][0]["seconds"], 10)
        self.assertEqual(samples["restart_to_boot"][0]["seconds"], 90)
        self.assertEqual(samples["restart_to_worker"][0]["seconds"], 110)
        self.assertEqual(samples["idle_claim_latency"][0]["seconds"], 10)
        self.assertEqual(incomplete[0]["boot_id"], "boot-b")

    def test_loader_deduplicates_active_and_compressed_rotation(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = pathlib.Path(temporary_directory)
            record = event("boot_started", 0, "boot-a", "event-1")
            (root / "events.jsonl").write_text(json.dumps(record) + "\n")
            with gzip.open(root / "events.jsonl.1.gz", "wt", encoding="utf-8") as rotated:
                rotated.write(json.dumps(record) + "\n")
            self.assertEqual(analyzer.load_events([root]), [record])

    def test_loader_skips_events_with_non_string_timestamps(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = pathlib.Path(temporary_directory)
            valid_record = event("boot_started", 0, "boot-a", "event-1")
            malformed_record = event("worker_started", 1, "boot-a", "event-2")
            malformed_record["event_time"] = None
            (root / "events.jsonl").write_text(
                json.dumps(malformed_record) + "\n" + json.dumps(valid_record) + "\n"
            )
            self.assertEqual(analyzer.load_events([root]), [valid_record])


if __name__ == "__main__":
    unittest.main()
