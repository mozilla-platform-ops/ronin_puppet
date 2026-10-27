"""Exercise the ERB-rendered Vagrant Ruby heredoc with stub package commands."""

import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

TEMPLATE = pathlib.Path(__file__).parents[1] / "vagrantfiles/Vagrantfile-debianoid.erb"
RENDER = '''
require 'erb'
module Vagrant
  def self.has_plugin?(_name); false; end
  def self.configure(_version); yield Node.new; end
  class Node
    def method_missing(name, *args, **kwargs, &block)
      if name == :provision
        print kwargs.fetch(:inline)
      else
        block.call(self) if block
        self
      end
    end
  end
end
config = {box: 'fixture', box_url: 'fixture', provider: 'virtualbox',
          network: [], synced_folders: [], customize: {}}
eval(ERB.new(File.read(ARGV.fetch(0))).result(binding), binding, ARGV.fetch(0))
'''
STUBS = '''
mktemp() {
    [ "$#" -eq 2 ] && [ "$1" = -d ] && [ "$2" = /root/puppet-release.XXXXXX ] || return 1
    directory=$(command mktemp -d "${TEST_ROOT}/puppet-release.XXXXXX") || return 1
    printf '%s\n' "$directory" > "${TEST_ROOT}/staging-path"
    printf '%s\n' "$directory"
}
lsb_release() {
    [ "$*" = '-c -s' ] || return 1
    [ "$SCENARIO" != codename_failure ] || return 1
    printf 'jammy\n'
}
wget() {
    [ "$#" -eq 4 ] && [ "$1" = --https-only ] && [ "$2" = -O ] || return 1
    [ "$4" = https://apt.puppetlabs.com/puppet5-release-jammy.deb ] || return 1
    "$TEST_PYTHON" -c 'import pathlib, sys; assert pathlib.Path(sys.argv[1]).parent.stat().st_mode & 0o777 == 0o700' "$3" || return 1
    printf '%s\n' "$3" > "${TEST_ROOT}/download-path"
    printf 'release package\n' > "$3"
    [ "$SCENARIO" != download_failure ]
}
dpkg() {
    [ "$#" -eq 2 ] && [ "$1" = -i ] || return 1
    [ "$2" = "$(cat "${TEST_ROOT}/download-path")" ] || return 1
    [ "$(cat "$2")" = 'release package' ] || return 1
    printf '%s\n' "$2" > "${TEST_ROOT}/install-path"
    [ "$SCENARIO" != install_failure ]
}
'''


class VagrantReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rendered = subprocess.run(["ruby", "-e", RENDER, str(TEMPLATE)],
                                      capture_output=True, text=True, check=True).stdout
        start = cls.rendered.index("    install_puppet_release() {")
        end = cls.rendered.index("    apt-get update", start)
        cls.install = cls.rendered[start:end]

    def test_rendered_script_and_install_function_validate(self):
        subprocess.run(["sh", "-n"], input=self.rendered, text=True, check=True)
        subprocess.run(["shellcheck", "-s", "sh", "-"], input=self.install, text=True, check=True)
        self.assertNotIn("/var/tmp/*.deb", self.rendered)
        self.assertNotIn("http://apt.puppetlabs.com", self.rendered)
        self.assertIn('trap \'rm -rf -- "${package_dir}"\' EXIT', self.rendered)
        self.assertIn('"https://apt.puppetlabs.com/puppet5-release-${codename}.deb"', self.rendered)

    def test_exact_package_and_cleanup_on_success_and_failures(self):
        for scenario in ("success", "codename_failure", "download_failure", "install_failure"):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory() as tmp:
                root = pathlib.Path(tmp)
                unrelated = root / "unrelated.deb"
                unrelated.write_text("unrelated package")
                script = STUBS + self.install + '\nprintf continued > "${TEST_ROOT}/continued"\n'
                result = subprocess.run(["sh", "-c", script], capture_output=True, text=True,
                                        env=dict(os.environ, TEST_ROOT=tmp, TEST_PYTHON=sys.executable, SCENARIO=scenario))
                self.assertEqual(result.returncode, 0 if scenario == "success" else 1, result.stderr)
                self.assertEqual((root / "continued").exists(), scenario == "success")
                staging = pathlib.Path((root / "staging-path").read_text().strip())
                self.assertFalse(staging.exists())
                self.assertEqual(unrelated.read_text(), "unrelated package")
                self.assertEqual((root / "install-path").exists(), scenario in ("success", "install_failure"))
                if (root / "install-path").exists():
                    self.assertEqual((root / "install-path").read_text(), (root / "download-path").read_text())


if __name__ == "__main__":
    unittest.main()
