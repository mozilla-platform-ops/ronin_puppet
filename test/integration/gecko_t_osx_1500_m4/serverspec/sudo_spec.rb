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
# executes code from it as uid 0. Guard both halves of the policy.
describe file('/etc/sudoers') do
  it 'does not preserve HOME across sudo' do
    expect(subject.content).not_to match(/^Defaults\s+env_keep\s*\+=\s*"[^"]*\bHOME\b/)
  end

  it 'forces HOME to the target user' do
    expect(subject.content).to match(/^Defaults\s+always_set_home\b/)
  end

  it 'still grants cltbld the reboot it needs' do
    expect(subject.content).to match(%r{^cltbld\s+ALL=\(root\)\s+NOPASSWD:\s+/sbin/reboot$})
  end
end

# This role runs a `multiuser*` engine, so worker-runner is already a root
# LaunchDaemon and its `sudo run-puppet.sh` is a no-op from root. The grant is
# therefore pure attack surface and must NOT be present.
describe file('/etc/sudoers') do
  it 'does not grant cltbld run-puppet.sh (worker-runner is already root)' do
    expect(subject.content).not_to match(%r{^cltbld\s+ALL=\(root\)\s+NOPASSWD:\s+/usr/local/bin/run-puppet\.sh$})
  end
end
