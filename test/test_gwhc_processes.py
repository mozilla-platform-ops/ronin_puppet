"""Exercise worker state detection using a temporary proc filesystem."""

import contextlib
import ctypes
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
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
    def test_verbose_output_includes_puppet_journal_command(self):
        with mock.patch.object(health, "_puppet_service_state", return_value=("activating", "start", "systemctl")), \
             mock.patch.object(health, "CHECKS", [("puppet", health.check_puppet)]):
            results = health.run_checks()
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            health.print_human(results, [], verbose=True)
        self.assertIn("~ journalctl -u run-puppet -b --no-pager", output.getvalue())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            health.print_human(results, [], verbose=False)
        self.assertNotIn("journalctl", output.getvalue())


if __name__ == "__main__":
    unittest.main()
