require_relative 'spec_helper'

describe file('/etc/sudoers') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 440 }
end

describe file('/etc/sudoers.d') do
  it { should_not exist }
end

# Bug 2064340: cltbld is the untrusted CI task user. If sudo lets it carry HOME
# across the privilege boundary, root's git reads the task's ~/.gitconfig and
# executes code from it as uid 0.
#
# Assertions go through `sudo grep -c` rather than file().content for two
# reasons. /etc/sudoers is 0440 root:wheel and serverspec's file().content
# shells out without sudo (`cat ... || echo -n`), so it yields the literal
# string "-n" and every should_not below would pass vacuously. And a count is a
# single ASCII digit, which keeps whole-file contents -- and any stray non-UTF-8
# byte in them -- out of the JUnit report, whose formatter cannot encode them.
#
# grep -c exits 1 when the count is 0, so exit_status is deliberately not
# asserted; the count itself is the assertion.

# Canary: proves the file is readable, so the zero-counts below mean something.
describe command("sudo grep -cE '^Defaults[[:space:]]+env_reset$' /etc/sudoers") do
  its(:stdout) { should match(/^1$/) }
end

describe command("sudo grep -cE '^Defaults[[:space:]]+env_keep.*HOME' /etc/sudoers") do
  its(:stdout) { should match(/^0$/) }
end

describe command("sudo grep -cE '^Defaults[[:space:]]+always_set_home$' /etc/sudoers") do
  its(:stdout) { should match(/^1$/) }
end

describe command("sudo grep -cE '^cltbld ALL=\\(root\\) NOPASSWD: /sbin/reboot$' /etc/sudoers") do
  its(:stdout) { should match(/^1$/) }
end

# This role runs a `multiuser*` engine, so worker-runner is already a root
# LaunchDaemon and its `sudo run-puppet.sh` is a no-op from root. The grant is
# therefore pure attack surface and must NOT be present.
describe command("sudo grep -cE '^cltbld ALL=\\(root\\) NOPASSWD: /usr/local/bin/run-puppet[.]sh$' /etc/sudoers") do
  its(:stdout) { should match(/^0$/) }
end
