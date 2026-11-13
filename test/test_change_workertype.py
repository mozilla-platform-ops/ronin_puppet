"""Worker-type overrides for legacy runners and direct generic-worker launches."""

import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import yaml

SCRIPT = Path(__file__).resolve().parents[1] / 'modules/puppet/files/change_workertype.py'
spec = importlib.util.spec_from_file_location('change_workertype', SCRIPT)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ChangeWorkerTypeTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.runner = self.root / 'start-worker.yml'
        self.worker = self.root / 'generic-worker.config'

    def test_default_prefers_runner_over_generated_legacy_json(self):
        self.worker.write_text('{}')
        with mock.patch.object(helper, 'RUNNER_CONFIG', self.runner), mock.patch.object(helper, 'WORKER_CONFIG', self.worker):
            self.assertEqual(helper.default_config(), self.worker)
            self.runner.write_text('provider: {}')
            self.assertEqual(helper.default_config(), self.runner)

    def test_json_override_preserves_credentials_identity_permissions_and_format(self):
        original = {'workerType': 'old-type', 'provisionerId': 'releng-hardware', 'workerGroup': 'mdc1',
                    'workerId': 'ms-017', 'clientId': 'test-client', 'accessToken': 'test-token'}
        self.worker.write_text(json.dumps(original))
        self.worker.chmod(0o600)
        before = self.worker.stat()
        result = subprocess.run([sys.executable, str(SCRIPT), '-f', str(self.worker), '-t', 'canary'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.worker.read_text()), {**original, 'workerType': 'canary'})
        after = self.worker.stat()
        self.assertEqual((after.st_uid, after.st_gid, stat.S_IMODE(after.st_mode)),
                         (before.st_uid, before.st_gid, 0o600))
        self.assertNotIn('test-token', result.stdout + result.stderr)

    def test_yaml_override_updates_both_worker_and_provider(self):
        self.runner.write_text(yaml.safe_dump({'provider': {'workerPoolID': 'releng-hardware/old'},
                                              'workerConfig': {'provisionerId': 'releng-hardware', 'workerType': 'old'}}))
        helper.change_workertype(self.runner, 'canary')
        data = yaml.safe_load(self.runner.read_text())
        self.assertEqual(data['provider']['workerPoolID'], 'releng-hardware/canary')
        self.assertEqual(data['workerConfig']['workerType'], 'canary')

    def test_parse_failure_does_not_truncate_config(self):
        original = '{invalid json'
        self.worker.write_text(original)
        with self.assertRaises(json.JSONDecodeError):
            helper.change_workertype(self.worker, 'canary')
        self.assertEqual(self.worker.read_text(), original)

    def test_failed_override_prevents_puppet_completion_marker(self):
        template = (SCRIPT.parents[1] / 'templates/puppet-ubuntu-run-puppet.sh.erb').read_text()
        tail = template[template.index('# override worker type with value'):]
        override = self.root / 'override'
        override.write_text('#!/bin/sh\nexit 1\n')
        override.chmod(0o755)
        marker = self.root / 'marker'
        marker.write_text('#!/bin/sh\ntouch "' + str(self.root / 'published') + '"\n')
        marker.chmod(0o755)
        tail = tail.replace('/usr/local/bin/change_workertype.py', str(override))
        tail = tail.replace('/usr/local/bin/puppet-run-marker', str(marker))
        prelude = "WORKER_TYPE_OVERRIDE=canary\nWRITE_SENTINEL=1\nfail() { exit 1; }\nlifecycle_log() { :; }\n"
        result = subprocess.run(['bash', '-c', prelude + tail], capture_output=True, text=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'published').exists())


if __name__ == '__main__':
    unittest.main()
