"""Installed Taskcluster version reporting, including legacy workers."""

from pathlib import Path
import runpy
import subprocess
import types
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / 'modules/linux_generic_worker/files/generic-worker-health-check'
health = runpy.run_path(str(SCRIPT))
check = health['check_tc_versions']


class VersionsTests(unittest.TestCase):
    def test_direct_worker_versions_and_optional_runner(self):
        with mock.patch('os.path.exists', side_effect=lambda p: not p.endswith('/start-worker')), \
             mock.patch('subprocess.run', return_value=types.SimpleNamespace(returncode=0, stdout='115.0.1\n', stderr='')) as run:
            status, detail, data = check()
        self.assertEqual(status, health['PASS'])
        self.assertEqual(run.call_count, 3)
        self.assertIn('generic-worker=115.0.1', detail)
        self.assertNotIn('start-worker=', detail)
        self.assertIsNone(data['versions']['start-worker'])
        self.assertEqual(data['versions']['taskcluster-proxy'], '115.0.1')

    def test_legacy_version_fallback_and_mixed_versions(self):
        def version(cmd, **kwargs):
            if cmd[-1] == '--short-version':
                return types.SimpleNamespace(returncode=1, stdout='', stderr='unsupported option')
            name = Path(cmd[0]).name
            value = '44.23.2' if name == 'start-worker' else '88.0.2'
            return types.SimpleNamespace(returncode=0, stdout=f'{name} {value} (revision abc)', stderr='')
        with mock.patch('os.path.exists', return_value=True), mock.patch('subprocess.run', side_effect=version):
            status, detail, data = check()
        self.assertEqual(status, health['PASS'])
        self.assertIn('start-worker=44.23.2', detail)
        self.assertEqual(data['versions']['generic-worker'], '88.0.2')

    def test_missing_unreadable_and_unresponsive_binaries_warn(self):
        for error in (PermissionError(), subprocess.TimeoutExpired('version', 3)):
            with self.subTest(error=error), mock.patch('os.path.exists', return_value=True), \
                 mock.patch('subprocess.run', side_effect=error):
                status, detail, data = check()
            self.assertEqual(status, health['WARN'])
            self.assertIn('generic-worker=unknown', detail)
        with mock.patch('os.path.exists', return_value=False), mock.patch('subprocess.run') as run:
            status, detail, data = check()
        self.assertEqual(status, health['WARN'])
        self.assertIn('livelog=not installed', detail)
        run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
