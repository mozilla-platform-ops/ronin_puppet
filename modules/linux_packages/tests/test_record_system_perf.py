import importlib.machinery
import importlib.util
import io
import os
import signal
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

SCRIPT = Path(__file__).parents[1] / "files" / "record-system-perf"
loader = importlib.machinery.SourceFileLoader("recorder", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
recorder = importlib.util.module_from_spec(spec)
loader.exec_module(recorder)


class RecorderTests(unittest.TestCase):
    def test_rejects_arguments_before_privileged_work(self):
        for arguments in (["--help"], ["record"], ["-o", "/etc/passwd"], ["/bin/sh"]):
            with (
                self.subTest(arguments=arguments),
                mock.patch.object(recorder.os, "geteuid") as geteuid,
            ):
                with self.assertRaisesRegex(RuntimeError, "no arguments"):
                    recorder.main(arguments)
                geteuid.assert_not_called()

    def test_rejects_wrong_identity(self):
        with mock.patch.object(recorder.os, "geteuid", return_value=1000):
            with self.assertRaisesRegex(RuntimeError, "via sudo"):
                recorder.main([])
        with (
            mock.patch.object(recorder.os, "geteuid", return_value=0),
            mock.patch.object(
                recorder.pwd, "getpwnam", return_value=SimpleNamespace(pw_uid=1000)
            ),
            mock.patch.dict(os.environ, {"SUDO_UID": "1001"}),
        ):
            with self.assertRaisesRegex(RuntimeError, "only cltbld"):
                recorder.main([])

    def test_rejects_symlink_state_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            link = Path(directory) / "link"
            link.symlink_to(directory)
            with mock.patch.object(recorder, "STATE_DIR", str(link)):
                with self.assertRaises(OSError):
                    recorder.open_state()

    def test_rejects_writable_state_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            os.chmod(directory, 0o777)
            with mock.patch.object(recorder, "STATE_DIR", directory):
                with self.assertRaisesRegex(RuntimeError, "root-owned"):
                    recorder.open_state()

    def run_collect(self, control=b"", exit_code=0):
        child = mock.Mock(returncode=exit_code)
        child.poll.side_effect = [None, None, exit_code]
        with mock.patch.object(
            recorder.subprocess, "Popen", return_value=child
        ) as popen:
            with mock.patch.object(
                recorder.select, "select", return_value=([0], [], [])
            ):
                with mock.patch.object(recorder.os, "read", return_value=control):
                    recorder.collect("/protected/perf.data")
        return child, popen

    def test_eof_finalizes_fixed_recording_with_clean_environment(self):
        with mock.patch.dict(
            os.environ, {"PERF_CONFIG": "/task/config", "HOME": "/task"}
        ):
            child, popen = self.run_collect()
        child.send_signal.assert_called_once_with(signal.SIGINT)
        args, kwargs = popen.call_args
        self.assertEqual(
            args[0],
            [
                "/usr/bin/timeout",
                "--signal=INT",
                "--kill-after=30",
                "4200",
                "/usr/bin/perf",
                "record",
                "-a",
                "-g",
                "-k",
                "mono",
                "-F",
                "1000",
                "--no-buildid-cache",
                "-o",
                "/protected/perf.data",
            ],
        )
        self.assertEqual(kwargs["env"]["PERF_CONFIG"], "/dev/null")
        self.assertEqual(kwargs["env"]["HOME"], "/root")
        self.assertTrue(kwargs["start_new_session"])
        self.assertEqual(kwargs["stdin"], subprocess.DEVNULL)

    def test_control_bytes_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "EOF only"):
            self.run_collect(b"x")

    def test_perf_failure_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "status 1"):
            self.run_collect(exit_code=1)

    def test_stuck_collector_kills_owned_process_group(self):
        child = mock.Mock(pid=1234)
        child.poll.return_value = None
        child.wait.side_effect = [subprocess.TimeoutExpired("perf", 30), 0]
        with mock.patch.object(recorder.os, "killpg") as killpg:
            with self.assertRaisesRegex(RuntimeError, "stop deadline"):
                recorder.stop_child(child)
        killpg.assert_called_once_with(1234, signal.SIGKILL)

    def test_recording_deadline_stops_collector(self):
        child = mock.Mock(returncode=0)
        child.poll.side_effect = [None, None]
        with (
            mock.patch.object(recorder.subprocess, "Popen", return_value=child),
            mock.patch.object(
                recorder.time, "monotonic", side_effect=[0, recorder.MAX_SECONDS + 1]
            ),
        ):
            with self.assertRaisesRegex(RuntimeError, "maximum duration"):
                recorder.collect("/protected/perf.data")
        child.send_signal.assert_called_once_with(signal.SIGINT)

    def test_file_and_core_limits(self):
        with mock.patch.object(recorder.resource, "setrlimit") as limit:
            recorder.limit_child()
        limit.assert_any_call(recorder.resource.RLIMIT_FSIZE, (recorder.MAX_BYTES,) * 2)
        limit.assert_any_call(recorder.resource.RLIMIT_CORE, (0, 0))

    def test_cleanup_and_privilege_drop_before_delivery(self):
        events = []
        output = io.BytesIO()
        original_copy = recorder.shutil.copyfileobj
        with tempfile.TemporaryDirectory() as directory:
            descriptor = os.open(directory, os.O_RDONLY)

            def collect(path):
                Path(path).write_bytes(b"PERFILE2-test-data")

            def deliver(source, destination):
                self.assertEqual(events, ["groups", "gid", "uid"])
                self.assertEqual(list(Path(directory).iterdir()), [])
                original_copy(source, destination)

            with (
                mock.patch.object(recorder, "STATE_DIR", directory),
                mock.patch.object(recorder, "open_state", return_value=descriptor),
                mock.patch.object(recorder, "collect", side_effect=collect),
                mock.patch.object(recorder.os, "geteuid", return_value=0),
                mock.patch.object(
                    recorder.pwd,
                    "getpwnam",
                    return_value=SimpleNamespace(pw_uid=1000, pw_gid=1000),
                ),
                mock.patch.dict(os.environ, {"SUDO_UID": "1000"}),
                mock.patch.object(recorder.os, "chdir"),
                mock.patch.object(recorder.os, "umask"),
                mock.patch.object(recorder.fcntl, "flock"),
                mock.patch.object(
                    recorder.os,
                    "setgroups",
                    side_effect=lambda _: events.append("groups"),
                ),
                mock.patch.object(
                    recorder.os, "setgid", side_effect=lambda _: events.append("gid")
                ),
                mock.patch.object(
                    recorder.os, "setuid", side_effect=lambda _: events.append("uid")
                ),
                mock.patch.object(
                    recorder.sys, "stdout", SimpleNamespace(buffer=output)
                ),
                mock.patch.object(recorder.shutil, "copyfileobj", side_effect=deliver),
            ):
                self.assertEqual(recorder.main([]), 0)
        self.assertEqual(output.getvalue(), b"PERFILE2-test-data")


if __name__ == "__main__":
    unittest.main()
