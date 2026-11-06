"""Worker task state from current-process status and journal evidence."""

import json
import os
from pathlib import Path
import runpy
import tempfile
import types
import unittest
from unittest import mock

health = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'modules/linux_generic_worker/files/generic-worker-health-check'))
check = health['_gw_task_state']


class TaskStateTests(unittest.TestCase):
    def test_startup_ready_idle_and_running_log_patterns(self):
        for log, expected in [
            ('Initialising feature Mounts/Caches...', 'starting'),
            ('All features initialised.', 'ready'),
            ('WORKER_METRICS {"eventType":"workerReady"}', 'ready'),
            ('No task claimed. Idle for 1m', 'idle'),
            ('No task claimed.\nTask found: abc', 'task running'),
            ('Executing command 0\nNo task claimed.', 'idle'),
            ('Executing command 0\nExiting worker with exit code 0', 'unknown (worker finishing task or exiting)'),
            ('unrelated log line', 'unknown (no matching log pattern)'),
        ]:
            with self.subTest(log=log), mock.patch.dict(check.__globals__, {'_worker_status_context': mock.Mock(side_effect=OSError())}), \
                 mock.patch('subprocess.run', return_value=types.SimpleNamespace(stdout=log)):
                self.assertEqual(check(123)[0], expected)

    def test_current_status_overrides_missing_log_patterns_and_stale_status_is_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'worker-status.json'
            path.write_text(json.dumps({'currentTaskIds': ['task-id']}))
            for started, expected in [(path.stat().st_mtime - 10, 'task running'),
                                      (path.stat().st_mtime + 10, 'idle')]:
                with self.subTest(started=started), mock.patch.dict(check.__globals__, {'_worker_status_context': lambda pid: (started, str(path))}), \
                     mock.patch('subprocess.run', return_value=types.SimpleNamespace(stdout='No task claimed.')) as journal:
                    self.assertEqual(check(123)[0], expected)
                    if expected == 'idle':
                        self.assertIn('--since', journal.call_args.args[0])
                    else:
                        journal.assert_not_called()

    def test_missing_status_does_not_mean_idle(self):
        with mock.patch.dict(check.__globals__, {'_worker_status_context': lambda pid: (1, '/missing/status')}), \
             mock.patch('subprocess.run', return_value=types.SimpleNamespace(stdout='')):
            self.assertEqual(check(123)[0], 'unknown (no journal output)')

    def test_unknown_is_not_summarized_as_idle(self):
        for task_state, expected in [('unknown', 'UNKNOWN'), ('starting', 'STARTING'), ('ready', 'READY'), ('idle', 'IDLE')]:
            with self.subTest(task_state=task_state):
                rows = [{'name': 'generic_worker_process', 'status': health['PASS'],
                         'data': {'generic_worker_pids': [123], 'task_state': task_state}}]
                self.assertEqual(health['summarize'](rows)[0], expected)


if __name__ == '__main__':
    unittest.main()
