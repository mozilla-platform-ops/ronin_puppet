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

# This role runs the `simple` worker engine, so worker-runner is a cltbld
# LaunchAgent and its `sudo run-puppet.sh` call is load-bearing. The grant must
# stay; run-puppet.sh pins its own environment as the second layer of defence.
describe file('/etc/sudoers') do
  it 'grants cltbld run-puppet.sh (simple engine needs it)' do
    expect(subject.content).to match(%r{^cltbld\s+ALL=\(root\)\s+NOPASSWD:\s+/usr/local/bin/run-puppet\.sh$})
  end
end

# The pinned root environment must be present in the deployed script, and must
# come before anything that reads user-level config.
describe file('/usr/local/bin/run-puppet.sh') do
  it { should exist }
  it { should be_owned_by 'root' }

  it 'pins HOME to root before any git call' do
    lines = subject.content.lines
    home = lines.index { |l| l =~ /^export HOME=\/var\/root$/ }
    first_git = lines.index { |l| l =~ /^\s*(git|CURRENT_REMOTE_URL=\$\(git)\s/ }
    expect(home).not_to be_nil
    expect(first_git).not_to be_nil
    expect(home).to be < first_git
  end

  it 'neutralises user-level git config' do
    expect(subject.content).to match(%r{^export GIT_CONFIG_GLOBAL=/dev/null$})
  end

  it 'leaves the system git config alone so vcsrepo safe.directory still works' do
    expect(subject.content).not_to match(/^export GIT_CONFIG_(NOSYSTEM|SYSTEM)=/)
  end
end
