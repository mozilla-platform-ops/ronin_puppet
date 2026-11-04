"""Exercise worker detection, journal queries, and health reports."""

import contextlib
import ctypes
import datetime
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "modules/linux_generic_worker/files/generic-worker-health-check"
loader = importlib.machinery.SourceFileLoader("gwhc_processes", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
health = importlib.util.module_from_spec(spec)
loader.exec_module(health)


class WorkerProcessTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.proc = Path(temporary.name)
        for patch in (
            mock.patch.object(health, "PROC_ROOT", str(self.proc)),
            mock.patch.object(health, "puppet_done", return_value=True),
            mock.patch.object(health, "_gw_task_state", return_value=("task running", "journalctl")),
            mock.patch.object(health, "_proc_descendants", return_value=3),
            mock.patch.object(health.os, "getloadavg", return_value=(1.0, 0.5, 0.2)),
        ):
            patch.start()
            self.addCleanup(patch.stop)

    def worker(self, pid=1234, state="S", comm="generic-worker", argv=b"", ppid=999):
        directory = self.proc / str(pid)
        directory.mkdir()
        (directory / "comm").write_text(comm + "\n")
        (directory / "cmdline").write_bytes(argv)
        (directory / "status").write_text(f"Name:\t{comm}\nState:\t{state} (description)\nPPid:\t{ppid}\n")
        return directory

    def test_zombie_with_empty_cmdline_fails_before_task_status_or_puppet_gate(self):
        self.worker(state="Z")
        for done in (True, False):
            with self.subTest(puppet_done=done):
                health.puppet_done.return_value = done
                status, detail, data = health.check_generic_worker_process()
                self.assertEqual(status, health.FAIL)
                self.assertIn("zombie", detail)
                self.assertEqual(data["generic_worker_pids"], [])
                self.assertEqual(data["zombie_pids"], [1234])
                self.assertEqual(data["processes"], [{"pid": 1234, "ppid": 999, "state": "Z"}])
                self.assertNotIn("task_state", data)
        health._gw_task_state.assert_not_called()
        health.puppet_done.assert_not_called()

    def test_live_idle_and_working_behavior(self):
        self.worker()
        for task, expected in (("idle", health.PASS), ("task running", health.WARN)):
            health._gw_task_state.return_value = (task, "journalctl")
            status, detail, data = health.check_generic_worker_process()
            self.assertEqual(status, expected)
            self.assertEqual(data["generic_worker_pids"], [1234])
            self.assertEqual(data["zombie_pids"], [])
            self.assertEqual(data["task_state"], task)
            self.assertEqual("do not reboot" in detail, task == "task running")

    def test_argv_basename_matching(self):
        self.worker(comm="other", argv=b"/usr/local/bin/generic-worker\0run\0")
        self.assertEqual(health.check_generic_worker_process()[0], health.WARN)

    def test_extra_processes_fail_including_live_and_zombie(self):
        self.worker()
        extra = self.worker(pid=1235)
        self.assertEqual(health.check_generic_worker_process()[0], health.FAIL)
        (extra / "status").write_text("State:\tZ (zombie)\nPPid:\t999\n")
        status, detail, data = health.check_generic_worker_process()
        self.assertEqual(status, health.FAIL)
        self.assertIn("zombie", detail)
        self.assertEqual(data["generic_worker_pids"], [1234])
        health._gw_task_state.assert_not_called()

    def test_disappearing_or_incomplete_status_fails_without_stale_task_status(self):
        directory = self.worker()
        status_file = directory / "status"
        status_file.unlink()
        for contents in (None, "State:\tS\n", "State:\t\nPPid:\t999\n", "State:\tS\nPPid:\tbad\n"):
            with self.subTest(contents=contents):
                if contents is not None:
                    status_file.write_text(contents)
                status, _, data = health.check_generic_worker_process()
                self.assertEqual(status, health.FAIL)
                self.assertEqual(data["generic_worker_pids"], [])
                self.assertEqual(data["unverified_pids"], [1234])
        health._gw_task_state.assert_not_called()

    def test_disappears_during_name_scan(self):
        directory = self.proc / "1234"
        directory.mkdir()
        self.assertEqual(health.find_procs_by_name("generic-worker"), [])
        self.assertEqual(health.check_generic_worker_process()[0], health.FAIL)
        health._gw_task_state.assert_not_called()

    def test_dead_process_not_counted_as_live(self):
        self.worker(state="X")
        status, _, data = health.check_generic_worker_process()
        self.assertEqual(status, health.FAIL)
        self.assertEqual(data["generic_worker_pids"], [])
        health._gw_task_state.assert_not_called()

    def test_zombie_reports_json_human_and_nonzero_exit(self):
        self.worker(state="Z")
        for puppet_status, puppet_data, expected_state in (
            (health.PASS, {"done_sentinel": True}, "DEGRADED"),
            (health.WARN, {"service_active_state": "activating"}, "DEGRADED"),
            (health.FAIL, {}, "DOWN"),
        ):
            # Even cleanup/provisioning must not hide the zombie failure.
            checks = [
                ("puppet", lambda: (puppet_status, "puppet state", puppet_data)),
                ("disk_free", lambda: (health.WARN, "cleanup running", {"cleaner_running": True})),
                ("generic_worker_process", health.check_generic_worker_process),
            ]
            for args in (["gwhc", "--json"], ["gwhc"]):
                with self.subTest(puppet=puppet_status, args=args):
                    output = io.StringIO()
                    with mock.patch.object(health, "CHECKS", checks), \
                         mock.patch("sys.argv", args), \
                         contextlib.redirect_stdout(output), \
                         contextlib.redirect_stderr(io.StringIO()), \
                         self.assertRaises(SystemExit) as exited:
                        health.main()
                    self.assertEqual(exited.exception.code, 1)
                    rendered = output.getvalue()
                    self.assertNotIn("do not reboot", rendered)
                    self.assertNotIn("g-w up", rendered)
                    if "--json" in args:
                        report = json.loads(rendered)
                        self.assertFalse(report["ok"])
                        self.assertEqual(report["state"], expected_state)
                        self.assertIn("zombie", report["state_description"])
                    else:
                        self.assertTrue(rendered.startswith(expected_state + " "))
                        self.assertIn("zombie", rendered.splitlines()[0])


@unittest.skipUnless(sys.platform == "linux", "requires the Linux proc filesystem")
class RealZombieTests(unittest.TestCase):
    def test_real_process_start_time_bounds_the_journal_query(self):
        with mock.patch.object(health.subprocess, "run", return_value=SimpleNamespace(
            returncode=0, stdout="No task claimed", stderr=""
        )) as run:
            state, _ = health._gw_task_state(os.getpid())
        self.assertEqual(state, "idle")
        command = run.call_args.args[0]
        started = float(command[command.index("--since") + 1][1:])
        now = datetime.datetime.now(datetime.timezone.utc).timestamp()
        self.assertLessEqual(started, now)
        self.assertGreaterEqual(started, health._boot_time().timestamp())

    def test_real_zombie_with_empty_cmdline(self):
        pid = os.fork()
        if pid == 0:
            # Linux PR_SET_NAME sets comm, which remains present after exit.
            result = ctypes.CDLL(None).prctl(15, b"generic-worker", 0, 0, 0)
            os._exit(0 if result == 0 else 1)
        try:
            # Wait for exit without reaping so the child remains a zombie.
            exited = os.waitid(os.P_PID, pid, os.WEXITED | os.WNOWAIT)
            self.assertEqual(exited.si_status, 0)
            self.assertEqual(Path(f"/proc/{pid}/cmdline").read_bytes(), b"")
            with mock.patch.object(health, "_gw_task_state") as task_status:
                status, detail, data = health.check_generic_worker_process()
            self.assertEqual(status, health.FAIL)
            self.assertIn("zombie", detail)
            self.assertIn(pid, data["zombie_pids"])
            self.assertIn({"pid": pid, "ppid": os.getpid(), "state": "Z"}, data["processes"])
            task_status.assert_not_called()
        finally:
            os.waitpid(pid, 0)


class PuppetCommandTests(unittest.TestCase):
    def test_last_run_checkout_metadata_in_verbose_output(self):
        with tempfile.TemporaryDirectory() as directory:
            metadata = Path(directory) / "metadata.json"
            for success in (True, False):
                metadata.write_text(json.dumps({
                    "success": success, "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "git_branch": "test-branch", "git_sha": "abcdef0123456789", "role": "test-role",
                }))
                with mock.patch.object(health, "PUPPET_METADATA", str(metadata)), \
                     mock.patch.object(health, "_boot_time", return_value=None), \
                     mock.patch.object(health, "puppet_done", return_value=True), \
                     mock.patch.object(health, "_puppet_service_state", return_value=("inactive", "dead", "systemctl")), \
                     mock.patch.object(health, "CHECKS", [("puppet", health.check_puppet)]):
                    results = health.run_checks()
                self.assertEqual(results[0]["data"]["git_branch"], "test-branch")
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    health.print_human(results, [], verbose=True)
                self.assertIn("Last run checkout: branch=test-branch, sha=abcdef0123456789", output.getvalue())

    def puppet_results(self):
        with mock.patch.object(health, "_puppet_service_state", return_value=("activating", "start", "systemctl")), \
             mock.patch.object(health, "CHECKS", [("puppet", health.check_puppet)]):
            return health.run_checks()

    def test_verbose_output_includes_labeled_troubleshooting_commands(self):
        results = self.puppet_results()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            health.print_human(results, [], verbose=True)
        self.assertIn("View logs (current boot): sudo journalctl -u run-puppet -b --no-pager", output.getvalue())
        self.assertIn("Service status: systemctl status run-puppet --no-pager", output.getvalue())
        self.assertNotIn("Check command:", output.getvalue())
        self.assertNotIn("Equivalent command:", output.getvalue())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            health.print_human(results, [], verbose=False)
        self.assertNotIn("journalctl", output.getvalue())

    def test_debug_includes_verbose_and_internal_commands(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            health.print_human(self.puppet_results(), [], debug=True)
        self.assertIn("View logs (current boot): sudo journalctl", output.getvalue())
        self.assertIn("Check command: systemctl", output.getvalue())
        self.assertIn("Equivalent command: journalctl", output.getvalue())

    def test_json_command_visibility(self):
        results = self.puppet_results()
        for verbose, debug in ((False, False), (True, False), (False, True)):
            with self.subTest(verbose=verbose, debug=debug):
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    health.print_json(results, [], verbose=verbose, debug=debug)
                check = json.loads(output.getvalue())["checks"][0]
                self.assertEqual("troubleshooting_commands" in check, verbose or debug)
                self.assertEqual("check_commands" in check, debug)
                self.assertEqual("check_command_equivalents" in check, debug)

    def test_replay_verbose_works_without_recorded_commands(self):
        for flag in ("--verbose", "--debug"):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--replay", str(SCRIPT.parent.parent / "tests/gwhc/fixtures/idle.json"), flag],
                capture_output=True, text=True, check=True,
            )
            self.assertIn("View logs (current boot): sudo journalctl", result.stdout)
            self.assertIn("Worker processes: ps -C generic-worker", result.stdout)
            self.assertIn("Last run checkout: branch=unknown, sha=unknown", result.stdout)


class JournalTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.proc = Path(temporary.name)
        (self.proc / "stat").write_text("btime 1700000000\n")
        worker = self.proc / "1234"
        worker.mkdir()
        # Include spaces and ')' inside comm to exercise stat field parsing.
        fields = ["S"] + ["0"] * 18 + ["250"]
        (worker / "stat").write_text("1234 (worker ) name) " + " ".join(fields))
        for patch in (
            mock.patch.object(health, "PROC_ROOT", str(self.proc)),
            mock.patch.object(health.os, "sysconf", return_value=100),
            mock.patch.object(health, "find_procs_by_name", return_value=[1234]),
            mock.patch.object(health.os.path, "isdir", return_value=False),
        ):
            patch.start()
            self.addCleanup(patch.stop)

    def test_task_query_excludes_prior_boot_and_prior_worker_logs(self):
        def journal(cmd, **kwargs):
            self.assertIn("-b", cmd)
            self.assertIn("--quiet", cmd)
            self.assertEqual(cmd[cmd.index("--since") + 1], "@1700000002.500000")
            # Simulate journalctl applying the requested boot/time bounds.
            entries = [(False, 1700000003, "Executing command"),
                       (True, 1700000001, "Starting task feature"),
                       (True, 1700000003, "worker starting")]
            since = float(cmd[cmd.index("--since") + 1][1:])
            stdout = "\n".join(message for boot, ts, message in entries if boot and ts >= since)
            return SimpleNamespace(returncode=0, stdout=stdout, stderr="")

        with mock.patch.object(health.subprocess, "run", side_effect=journal):
            state, command = health._gw_task_state(1234)
        self.assertTrue(state.startswith("unknown"))
        self.assertIn("--since @1700000002.500000", command)

    def test_task_patterns_and_empty_query(self):
        for stdout, expected in (
            ("Starting task feature\nExecuting command", "task running"),
            ("Executing command\nNo task claimed", "idle"),
            ("", "unknown (no journal output)"),
        ):
            with self.subTest(stdout=stdout), mock.patch.object(
                health.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=stdout, stderr="")
            ):
                self.assertEqual(health._gw_task_state(1234)[0], expected)

    def test_failed_task_query_does_not_trust_stdout(self):
        with mock.patch.object(health.subprocess, "run", return_value=SimpleNamespace(
            returncode=1, stdout="Executing command", stderr="Permission denied"
        )):
            state, _ = health._gw_task_state(1234)
        self.assertIn("unknown (journalctl exit 1: Permission denied)", state)

    def test_missing_start_time_does_not_query_unscoped_logs(self):
        for path in (self.proc / "1234/stat", self.proc / "stat"):
            with self.subTest(path=path):
                contents = path.read_text()
                path.unlink()
                with mock.patch.object(health.subprocess, "run") as run:
                    self.assertTrue(health._gw_task_state(1234)[0].startswith("unknown"))
                    run.assert_not_called()
                path.write_text(contents)

    def test_freshness_requires_success_and_an_entry(self):
        for code, stdout, expected_status, recent in (
            (1, "diagnostic text", health.WARN, None),
            (0, "", health.WARN, False),
            (0, "No task claimed", health.PASS, True),
        ):
            with self.subTest(code=code, stdout=stdout), mock.patch.object(
                health.subprocess, "run", return_value=SimpleNamespace(returncode=code, stdout=stdout, stderr="error")
            ) as run:
                status, detail, data = health.check_worker_runner_process()
                self.assertEqual(status, expected_status)
                self.assertEqual(data.get("journal_recent"), recent)
                if code:
                    self.assertIn("journal query failed", detail)
                    self.assertIn("exit 1", data["journal_error"])
                command = run.call_args.args[0]
                self.assertIn("-b", command)
                self.assertIn("--quiet", command)
                self.assertIn("--since '15 minutes ago'", data["check_cmds"][0])

    def test_journal_exceptions_are_unknown(self):
        for error in (FileNotFoundError("journalctl"), subprocess.TimeoutExpired("journalctl", 5)):
            with self.subTest(error=error), mock.patch.object(health.subprocess, "run", side_effect=error):
                self.assertTrue(health._gw_task_state(1234)[0].startswith("unknown"))
                status, detail, data = health.check_worker_runner_process()
                self.assertEqual(status, health.WARN)
                self.assertIn("journal query failed", detail)
                self.assertIn("journal_error", data)

    def test_unknown_task_state_warns_without_reboot_advice(self):
        with mock.patch.object(health, "_worker_process_info", return_value={"pid": 1234, "ppid": 999, "state": "S"}), \
             mock.patch.object(health.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout="Executing command", stderr="error")):
            status, detail, _ = health.check_generic_worker_process()
        self.assertEqual(status, health.WARN)
        self.assertIn("unknown", detail)
        self.assertNotIn("do not reboot", detail)


class SummaryFailureTests(unittest.TestCase):
    def test_unknown_activity_is_warning_with_unknown_headline(self):
        for task_state in (None, "unknown (no journal output)", "unknown (journalctl exit 1: error)"):
            checks = [{
                "name": "generic_worker_process", "status": health.WARN, "detail": "task state unknown",
                "data": {"generic_worker_pids": [1234]},
            }]
            if task_state is not None:
                checks[0]["data"]["task_state"] = task_state
            for args in (["gwhc"], ["gwhc", "--json"]):
                with self.subTest(task_state=task_state, args=args):
                    output = io.StringIO()
                    with mock.patch.object(health, "run_checks", return_value=checks), \
                         mock.patch("sys.argv", args), contextlib.redirect_stdout(output), \
                         contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as exited:
                        health.main()
                    self.assertEqual(exited.exception.code, 0)
                    if "--json" in args:
                        report = json.loads(output.getvalue())
                        self.assertTrue(report["ok"])
                        self.assertEqual(report["state"], "UNKNOWN")
                        self.assertIn("verify activity before rebooting", report["state_description"])
                    else:
                        self.assertTrue(output.getvalue().startswith("UNKNOWN "))
                        self.assertIn("verify activity before rebooting", output.getvalue())

    def test_failures_override_idle_working_provisioning_and_cleanup(self):
        for failed_check in ("disk_free", "clock_skew", "task_dir_size"):
            for task in ("idle", "task running", "unknown (no journal output)"):
                for background in ({}, {"provisioning": True}, {"cleanup": True}):
                    checks = [
                        {"name": "puppet", "status": health.PASS, "detail": "passed", "data": {}},
                        {"name": "generic_worker_process", "status": health.PASS, "detail": "running",
                         "data": {"generic_worker_pids": [1234], "task_state": task}},
                        {"name": failed_check, "status": health.FAIL, "detail": "test failure", "data": {}},
                    ]
                    if background.get("provisioning"):
                        checks[0].update(status=health.WARN, data={"service_active_state": "activating"})
                    if background.get("cleanup"):
                        disk = next((r for r in checks if r["name"] == "disk_free"), None)
                        if disk:
                            disk["data"]["cleaner_running"] = True
                        else:
                            checks.append({"name": "disk_free", "status": health.WARN, "detail": "cleanup", "data": {"cleaner_running": True}})
                    with self.subTest(check=failed_check, task=task, background=background):
                        for args in (["gwhc"], ["gwhc", "--json"]):
                            output = io.StringIO()
                            with mock.patch.object(health, "run_checks", return_value=checks), \
                                 mock.patch("sys.argv", args), \
                                 contextlib.redirect_stdout(output), \
                                 contextlib.redirect_stderr(io.StringIO()), \
                                 self.assertRaises(SystemExit) as exited:
                                health.main()
                            self.assertEqual(exited.exception.code, 1)
                            if "--json" in args:
                                report = json.loads(output.getvalue())
                                self.assertFalse(report["ok"])
                                self.assertEqual(report["state"], "DEGRADED")
                                self.assertIn(failed_check, report["state_description"])
                            else:
                                self.assertTrue(output.getvalue().startswith("DEGRADED "))
                                self.assertIn(failed_check, output.getvalue().splitlines()[0])

    def test_cleanup_does_not_hide_puppet_failure(self):
        results = [
            {"name": "puppet", "status": health.FAIL, "detail": "last run failed", "data": {}},
            {"name": "disk_free", "status": health.WARN, "detail": "cleanup", "data": {"cleaner_running": True}},
        ]
        state, detail = health.summarize(results)
        self.assertEqual(state, "DOWN")
        self.assertIn("puppet: last run failed", detail)


if __name__ == "__main__":
    unittest.main()
