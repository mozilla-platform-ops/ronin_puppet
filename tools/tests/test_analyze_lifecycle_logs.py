import csv
import datetime
import gzip
import importlib.machinery
import importlib.util
import io
import json
import pathlib
import subprocess
import sys
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
    def test_csv_cell_neutralizes_formulas_and_leading_controls(self):
        for prefix in ("=", "+", "-", "@", "\t", "\r", "\n"):
            for leading in ("", " ", "  \t", "\x00", "\x1b", "\x85", "\u200b", "\u202e"):
                value = leading + prefix + 'SUM(1,2)'
                with self.subTest(value=value):
                    self.assertEqual(analyzer.csv_cell(value), "'" + value)

    def test_csv_cell_preserves_normal_strings_and_numeric_types(self):
        for value in ("", "host-a", "t-linux64-ms-001", "café", "combined", "  host-a", "'=1", 1, -2, 3.5, None):
            with self.subTest(value=value):
                safe = analyzer.csv_cell(value)
                self.assertEqual(safe, value)
                self.assertIs(type(safe), type(value))

    def test_cli_csv_neutralizes_cells_and_preserves_json_and_numbers(self):
        hosts = ['=HYPERLINK("https://example.invalid","click")', '+1', '-1', '@SUM(1,2)',
                 '\t=1', '\r=1', '\n=1', '  =1', '\x00=1', '\u200b=1',
                 'host-a', 't-linux64-ms-001', '  host-a', "'=1"]
        records = []
        for index, host in enumerate(hosts):
            records.extend([
                event("boot_started", 0, "boot-a", str(index * 2), host_id=host),
                event("puppet_run_started", 10.5, "boot-a", str(index * 2 + 1), host_id=host),
            ])
        with tempfile.TemporaryDirectory() as temporary_directory:
            source = pathlib.Path(temporary_directory) / "events.jsonl"
            source.write_text("".join(json.dumps(record) + "\n" for record in records))
            output = subprocess.run([sys.executable, str(ANALYZER_PATH), str(source), "--format", "csv"],
                                    capture_output=True, check=True).stdout.decode("utf-8")
            rows = list(csv.DictReader(io.StringIO(output, newline="")))
            self.assertEqual(len(rows), len(hosts) + 1)
            expected = ["'" + host for host in hosts[:10]] + hosts[10:]
            self.assertCountEqual([row["scope"] for row in rows if row["scope"] != "combined"], expected)
            for row in rows:
                self.assertEqual(row["measurement"], "early_host_startup")
                self.assertEqual(int(row["count"]), len(hosts) if row["scope"] == "combined" else 1)
                for field in ("p50_seconds", "p95_seconds", "max_seconds"):
                    self.assertEqual(float(row[field]), 10.5)
            result = subprocess.run([sys.executable, str(ANALYZER_PATH), str(source), "--format", "json"],
                                    capture_output=True, text=True, check=True)
            original_rows = json.loads(result.stdout)["percentiles"]
            self.assertCountEqual([row["scope"] for row in original_rows if row["scope"] != "combined"], hosts)

    def test_terminal_text_preserves_printable_text_and_escapes_controls(self):
        ordinary = "t-linux64-ms-001 café 日本語 \\literal"
        self.assertEqual(analyzer.terminal_text(ordinary), ordinary)
        self.assertEqual(analyzer.terminal_text("\x1b]52;c;payload\x07\r\n\t"),
                         r"\x1b]52;c;payload\x07\r\n\t")
        controls = "".join(chr(code) for code in list(range(32)) + list(range(127, 160)))
        escaped = analyzer.terminal_text(controls + "\u202e\u200b\u2028\u2029")
        self.assertTrue(escaped.isprintable())
        self.assertTrue(escaped.isascii())
        for character in controls:
            self.assertNotIn(character, escaped)
        self.assertIn(r"\u202e", escaped)
        self.assertIn(r"\x9b", escaped)

    def test_terminal_report_escapes_every_displayed_string_without_mutating_data(self):
        payload = "bad\x1b]52;c;clipboard\x07\r\n\x9b2K"
        rows = [{"measurement": payload, "scope": payload, "count": 1,
                 "p50_seconds": 10, "p95_seconds": 10, "max_seconds": 10}]
        incomplete = [{"host": payload, "boot_id": payload,
                       "final_event": payload, "final_event_time": payload}]
        original = json.dumps([rows, incomplete])
        report = analyzer.terminal_report(rows, incomplete)
        self.assertEqual(report.count(analyzer.terminal_text(payload)), 5)
        self.assertEqual(len(report.splitlines()), 4)
        self.assertTrue(all(character.isprintable() or character == "\n" for character in report))
        self.assertEqual(json.dumps([rows, incomplete]), original)

    def test_normal_terminal_report_layout_is_preserved(self):
        rows = [{"measurement": "puppet_run", "scope": "host-a", "count": 1,
                 "p50_seconds": 30, "p95_seconds": 30, "max_seconds": 30}]
        incomplete = [{"host": "host-a", "boot_id": "boot-b", "final_event": "worker_started"}]
        expected = (
            "measurement                 scope       count     p50     p95     max\n"
            + "{:<27} {:<11} {:>5} {:>7.1f} {:>7.1f} {:>7.1f}".format("puppet_run", "host-a", 1, 30, 30, 30)
            + "\nincomplete observed boots: 1\n  host-a boot-b: worker_started"
        )
        self.assertEqual(analyzer.terminal_report(rows, incomplete), expected)

    def test_cli_escapes_collected_events_but_preserves_json_values(self):
        controls = "".join(chr(code) for code in list(range(32)) + list(range(127, 160)))
        payload = "worker\x1b]52;c;clipboard\x07" + controls
        records = [
            event("boot_started", 0, payload, "1", host_id=payload),
            event("puppet_run_started", 10, payload, "2", host_id=payload),
            event(payload, 20, payload, "3", host_id=payload),
        ]
        with tempfile.TemporaryDirectory() as temporary_directory:
            source = pathlib.Path(temporary_directory) / "events.jsonl"
            source.write_text("".join(json.dumps(record) + "\n" for record in records))
            terminal = subprocess.run([sys.executable, str(ANALYZER_PATH), str(source)],
                                      capture_output=True, text=True, check=True).stdout
            self.assertTrue(all(character.isprintable() or character == "\n" for character in terminal))
            self.assertIn(analyzer.terminal_text(payload), terminal)
            self.assertEqual(len(terminal.splitlines()), 5)
            result = subprocess.run([sys.executable, str(ANALYZER_PATH), str(source), "--format", "json"],
                                    capture_output=True, text=True, check=True)
            report = json.loads(result.stdout)
            self.assertIn(payload, [row["scope"] for row in report["percentiles"]])
            item = report["incomplete_lifecycles"][0]
            for key in ("host", "boot_id", "final_event"):
                self.assertEqual(item[key], payload)

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
