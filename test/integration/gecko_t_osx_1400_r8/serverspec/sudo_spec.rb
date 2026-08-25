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

# This role runs the `simple` worker engine, so worker-runner is a cltbld
# LaunchAgent and its `sudo run-puppet.sh` call is load-bearing. The grant must
# stay; run-puppet.sh pins its own environment as the second layer of defence.
describe command("sudo grep -cE '^cltbld ALL=\\(root\\) NOPASSWD: /usr/local/bin/run-puppet[.]sh$' /etc/sudoers") do
  its(:stdout) { should match(/^1$/) }
end

describe file('/usr/local/bin/run-puppet.sh') do
  it { should exist }
  it { should be_owned_by 'root' }
end

describe command("grep -c '^export HOME=/var/root$' /usr/local/bin/run-puppet.sh") do
  its(:stdout) { should match(/^1$/) }
end

describe command("grep -c '^export GIT_CONFIG_GLOBAL=/dev/null$' /usr/local/bin/run-puppet.sh") do
  its(:stdout) { should match(/^1$/) }
end

# The system git config must stay live: puppet apply inherits this environment
# and reprovision_runner's vcsrepo writes safe.directory with `git config --system`.
describe command("grep -cE '^export GIT_CONFIG_(NOSYSTEM|SYSTEM)=' /usr/local/bin/run-puppet.sh") do
  its(:stdout) { should match(/^0$/) }
end

# HOME must be pinned before the first git invocation, not merely present.
describe command("awk '/^export HOME=\\/var\\/root$/{h=NR} /^[[:space:]]*(git|CURRENT_REMOTE_URL=[$][(]git)[[:space:]]/{if(!g)g=NR} END{print (h>0 && g>0 && h<g) ? \"OK\" : \"BAD\"}' /usr/local/bin/run-puppet.sh") do
  its(:stdout) { should match(/^OK$/) }
end
