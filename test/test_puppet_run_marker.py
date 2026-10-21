"""Marker security tests; local fixtures simulate root ownership when needed."""

import datetime
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import types
import unittest
from unittest import mock

REPO = pathlib.Path(__file__).parents[1]


def load_script(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


marker = load_script("puppet_marker", REPO / "modules/puppet/files/puppet-run-marker")
health = load_script("gwhc", REPO / "modules/linux_generic_worker/files/generic-worker-health-check")
BOOT = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee\n"


class MarkerTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name)
        self.runtime = self.root / "run"
        self.runtime.mkdir(mode=0o755)
        self.directory = self.runtime / "puppet"
        self.path = self.directory / "run_done"
        self.boot = self.root / "boot_id"
        self.boot.write_text(BOOT)
        self.overrides = {}
        real_fstat = os.fstat

        def fixture_stat(fd):
            info = real_fstat(fd)
            values = dict(st_mode=info.st_mode, st_uid=0, st_gid=0, st_nlink=info.st_nlink)
            values.update(self.overrides.get(info.st_ino, {}))
            return types.SimpleNamespace(**values)

        for patch in (
            mock.patch.object(marker, "RUNTIME_ROOT", str(self.runtime)),
            mock.patch.object(marker, "BOOT_ID", str(self.boot)),
            mock.patch.object(marker.os, "fstat", side_effect=fixture_stat),
            mock.patch.object(marker.os, "geteuid", return_value=0),
        ):
            patch.start()
            self.addCleanup(patch.stop)
        if os.getuid() != 0:
            patch = mock.patch.object(marker.os, "fchown")
            patch.start()
            self.addCleanup(patch.stop)

    def valid(self):
        try:
            return marker.marker_operation()
        except (OSError, ValueError):
            return False

    def publish(self):
        return marker.marker_operation(publish=True)

    def test_success_and_boot_change(self):
        self.assertFalse(self.valid())
        self.assertTrue(self.publish())
        self.assertTrue(self.valid())
        self.assertEqual(self.path.read_text(), BOOT)
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o755)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o644)
        self.boot.write_text("11111111-2222-3333-4444-555555555555\n")
        self.assertFalse(self.valid())
        self.assertTrue(self.publish())
        self.assertTrue(self.valid())

    def test_legacy_marker_ignored(self):
        (self.root / "puppet_run_done").touch()
        self.assertFalse(self.valid())

    def test_symlink_and_hardlink_not_followed(self):
        self.directory.mkdir()
        target = self.root / "unrelated"
        target.write_text(BOOT)
        for kind in ("symlink", "hardlink"):
            if kind == "symlink":
                self.path.symlink_to(target)
            else:
                os.link(target, self.path)
            self.assertFalse(self.valid())
            self.publish()
            self.assertTrue(self.valid())
            self.assertEqual(target.read_text(), BOOT)
            self.assertNotEqual(self.path.stat().st_ino, target.stat().st_ino)
            self.path.unlink()

    def test_directory_symlink_and_unsafe_directories(self):
        target = self.root / "attacker"
        target.mkdir()
        self.directory.symlink_to(target)
        self.assertFalse(self.valid())
        with self.assertRaises(OSError):
            self.publish()
        self.assertEqual(list(target.iterdir()), [])
        self.directory.unlink()
        self.publish()
        for directory in (self.runtime, self.directory):
            for mode in (0o775, 0o777):
                directory.chmod(mode)
                self.assertFalse(self.valid())
                with self.assertRaises(OSError):
                    self.publish()
            directory.chmod(0o755)
            self.overrides[directory.stat().st_ino] = {"st_uid": 1000}
            self.assertFalse(self.valid())
            with self.assertRaises(OSError):
                self.publish()
            self.overrides.clear()

    def test_bad_file_owner_group_permissions_type_and_content(self):
        self.publish()
        for field in ("st_uid", "st_gid"):
            self.overrides[self.path.stat().st_ino] = {field: 1000}
            self.assertFalse(self.valid())
        self.overrides.clear()
        for mode in (0o664, 0o666):
            self.path.chmod(mode)
            self.assertFalse(self.valid())
        self.path.chmod(0o644)
        self.path.write_text(BOOT + "extra")
        self.assertFalse(self.valid())
        self.path.unlink()
        os.mkfifo(self.path)
        self.assertFalse(self.valid())
        self.path.unlink()
        self.path.mkdir()
        self.assertFalse(self.valid())

    def test_unprivileged_publish_and_failed_publish(self):
        with mock.patch.object(marker.os, "geteuid", return_value=1000):
            with self.assertRaises(PermissionError):
                self.publish()
        with mock.patch.object(marker.os, "replace", side_effect=OSError("failed publish")):
            with self.assertRaises(OSError):
                self.publish()
        self.assertFalse(self.valid())
        self.assertEqual(list(self.directory.iterdir()), [])

    def test_restrictive_umask(self):
        previous = os.umask(0o077)
        try:
            self.publish()
        finally:
            os.umask(previous)
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o755)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o644)

    def test_atomic_publish_keeps_previous_success_on_failure(self):
        self.publish()
        with mock.patch.object(marker.os, "replace", side_effect=OSError("failed publish")):
            with self.assertRaises(OSError):
                self.publish()
        self.assertTrue(self.valid())
        self.assertEqual([p.name for p in self.directory.iterdir()], ["run_done"])


class ConsumerTests(unittest.TestCase):
    def test_producer_publishes_only_after_success_unless_disabled(self):
        template = (REPO / "modules/puppet/templates/puppet-ubuntu-run-puppet.sh.erb").read_text()
        tail = template[template.index("# Normal boot/worker execution retries"):]
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp)
            helper = path / "helper"
            helper.write_text('#!/bin/sh\n[ "$1" = publish ] || exit 2\ntouch "' + tmp + '/published"\nexit "${PUBLISH_STATUS:-0}"\n')
            helper.chmod(0o755)
            tail = tail.replace('/usr/local/bin/puppet-run-marker', str(helper))
            for success, enabled, publish_status, expected_exit, expected_publish in (
                (True, 1, 0, 0, True), (False, 1, 0, 1, False),
                (True, 0, 0, 0, False), (True, 1, 1, 1, True),
            ):
                published = path / "published"
                if published.exists():
                    published.unlink()
                prelude = '''
FLEETROLL_SINGLE_RUN=1
WORKER_TYPE_OVERRIDE=''
lifecycle_log() { :; }
configure_git_auth() { :; }
fail() { exit 1; }
'''
                prelude += 'WRITE_SENTINEL={}\nexport PUBLISH_STATUS={}\nrun_puppet() {{ return {}; }}\n'.format(enabled, publish_status, 0 if success else 1)
                result = subprocess.run(["bash", "-c", prelude + tail], capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, expected_exit, result.stderr)
                self.assertEqual(published.exists(), expected_publish)

    def test_health_checker_uses_helper_and_fails_closed(self):
        for exit_code in (0, 1):
            with mock.patch.object(health.subprocess, "run", return_value=types.SimpleNamespace(returncode=exit_code)) as run:
                self.assertEqual(health.puppet_done(), exit_code == 0)
                self.assertEqual(run.call_args[0][0], ["/usr/local/bin/puppet-run-marker", "check"])
        for error in (FileNotFoundError(), subprocess.TimeoutExpired("helper", 5)):
            with mock.patch.object(health.subprocess, "run", side_effect=error):
                self.assertFalse(health.puppet_done())

    def test_health_checks_reject_unsafe_signal(self):
        with mock.patch.object(health, "find_procs_by_name", return_value=[]):
            for valid, expected in ((False, health.WARN), (True, health.FAIL)):
                with mock.patch.object(health, "puppet_done", return_value=valid):
                    self.assertEqual(health.check_generic_worker_process()[0], expected)
        with tempfile.TemporaryDirectory() as tmp:
            metadata = pathlib.Path(tmp) / "metadata.json"
            metadata.write_text(json.dumps({"success": True, "ts": datetime.datetime.now(datetime.timezone.utc).isoformat()}))
            with mock.patch.object(health, "PUPPET_METADATA", str(metadata)), \
                 mock.patch.object(health, "_boot_time", return_value=None), \
                 mock.patch.object(health, "_puppet_service_state", return_value=("inactive", "dead", "systemctl")):
                for valid, expected in ((False, health.WARN), (True, health.PASS)):
                    with mock.patch.object(health, "puppet_done", return_value=valid):
                        status, _, data = health.check_puppet()
                        self.assertEqual(status, expected)
                        self.assertEqual(data["done_sentinel"], valid)

    def test_rendered_worker_gate_waits_for_helper(self):
        template = (REPO / "modules/linux_generic_worker/templates/run-start-worker.sh.erb").read_text()
        gate = template.split("# wait for puppet to finish before starting", 1)[1].split("# First run the start-worker", 1)[0]
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp)
            helper = path / "helper"
            # Two refusals (initial check and first loop), then success.
            helper.write_text('#!/bin/sh\nn=$(cat "' + tmp + '/count" 2>/dev/null || echo 0)\nn=$((n+1))\necho "$n" > "' + tmp + '/count"\n[ "$n" -ge 3 ]\n')
            helper.chmod(0o755)
            script = 'set -e\nsleep() { :; }\n' + gate.replace('/usr/local/bin/puppet-run-marker', str(helper)) + '\necho released\n'
            result = subprocess.run(["bash", "-c", script], text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("released", result.stdout)
            self.assertEqual((path / "count").read_text().strip(), "3")


@unittest.skipUnless(os.getuid() == 0, "real uid separation requires a root Linux container")
class RootPermissionTests(unittest.TestCase):
    def test_task_user_can_check_but_cannot_forge_or_publish(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            root.chmod(0o755)
            runtime = root / "run"
            runtime.mkdir(mode=0o755)
            boot = root / "boot_id"
            boot.write_text(BOOT)
            with mock.patch.object(marker, "RUNTIME_ROOT", str(runtime)), \
                 mock.patch.object(marker, "BOOT_ID", str(boot)):
                marker.marker_operation(publish=True)
                pid = os.fork()
                if pid == 0:
                    try:
                        os.setgroups([])
                        os.setgid(65534)
                        os.setuid(65534)
                        assert marker.marker_operation()
                        for operation in (
                            lambda: (runtime / "puppet" / "run_done").write_text("forged"),
                            lambda: (runtime / "puppet" / "extra").touch(),
                            lambda: marker.marker_operation(publish=True),
                        ):
                            try:
                                operation()
                            except PermissionError:
                                continue
                            raise AssertionError("task user modified marker state")
                    except Exception:
                        os._exit(1)
                    os._exit(0)
                _, status = os.waitpid(pid, 0)
                self.assertEqual(status, 0, "unprivileged marker checks/write rejection failed")
                self.assertTrue(marker.marker_operation())


if __name__ == "__main__":
    unittest.main()
