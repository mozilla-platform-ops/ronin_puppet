"""Verify a catalog-updated metadata writer is used in the same Puppet run."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / 'modules/puppet/templates/puppet-ubuntu-run-puppet.sh.erb'
WRITER = ROOT / 'modules/puppet/files/puppet_state_functions.sh'


class StateWriterRefreshTests(unittest.TestCase):
    def test_updated_writer_records_selected_branch_on_first_run(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            repo = directory / 'repo'
            repo.mkdir()
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            subprocess.run(['git', '-C', str(repo), '-c', 'user.name=Test',
                            '-c', 'user.email=test@example.invalid', 'commit',
                            '--allow-empty', '-qm', 'test'], check=True)
            subprocess.run(['git', '-C', str(repo), 'checkout', '--detach', '-q'], check=True)
            writer = directory / 'writer.sh'
            writer.write_text(WRITER.read_text())
            metadata = directory / 'metadata.json'
            template = TEMPLATE.read_text()
            start = template.index('    if type write_puppet_state >/dev/null 2>&1; then')
            end = template.index('    # ==============================================================================', start)
            block = template[start:end].replace('/etc/puppet/lib/puppet_state_functions.sh', str(writer))
            block = block.replace('"/etc/puppet/ronin_settings" "/root/vault.yaml" 2>&1',
                                  f'"{directory}/override" "{directory}/vault" "{metadata}" 2>&1')
            script = 'write_puppet_state() { echo stale-writer; }\n' + block
            env = dict(os.environ, WORKING_DIR=str(repo), ROLE='test-role', retval='0',
                       PUPPET_RUN_DURATION='1', PUPPET_BRANCH='feature/test')
            subprocess.run(['bash', '-c', script], env=env, check=True, capture_output=True, text=True)
            state = json.loads(metadata.read_text())
            self.assertEqual(state['git_branch'], 'feature/test')
            self.assertTrue(state['success'])


if __name__ == '__main__':
    unittest.main()
