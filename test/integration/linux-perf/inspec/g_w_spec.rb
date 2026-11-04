require_relative 'spec_helper'

# binaries

describe command('generic-worker --version') do
  its(:exit_status) { should eq 0 }
    # TODO: check version?
  its(:stdout) { should match /generic-worker/ }
end

describe file('/usr/local/bin/generic-worker') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/local/bin/livelog') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/local/bin/taskcluster-proxy') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/local/bin/start-worker') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/local/bin/quarantine-worker') do
  it { should_not exist }
end

describe file('/usr/local/share/generic-worker/bugzilla-utils.sh') do
  it { should_not exist }
end

describe file('/usr/local/bin/run-start-worker.sh') do
  it { should exist }
  it { should be_executable }
  its('content') { should_not match /TASKCLUSTER_ACCESS_TOKEN|quarantine-worker/ }
end

describe file('/usr/local/bin/run-generic-worker.sh') do
  it { should_not exist }
end

# config

start_worker_version = command('/usr/local/bin/start-worker --short-version').stdout.strip.sub(/\Av/, '')
generic_worker_version = command('/usr/local/bin/generic-worker --short-version').stdout.strip.sub(/\Av/, '')

describe file('/etc/start-worker.yml') do
  it { should exist }
  if Gem::Version.new(start_worker_version) >= Gem::Version.new('115.0.1')
    its('owner') { should eq 'cltbld' }
    its('group') { should eq 'cltbld' }
    its('mode') { should cmp '0600' }
    it { should be_readable.by_user('cltbld') }
  else
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode') { should cmp '0644' }
  end
end

describe yaml('/etc/start-worker.yml') do
  if Gem::Version.new(start_worker_version) >= Gem::Version.new('115.0.0')
    its(['cacheOverRestarts']) { should eq '' }
  else
    its(['cacheOverRestarts']) { should eq true }
  end

  if Gem::Version.new(generic_worker_version) >= Gem::Version.new('115.0.0')
    its(['workerConfig']) { should_not have_key('checkForNewDeploymentEverySecs') }
  else
    its(['workerConfig', 'checkForNewDeploymentEverySecs']) { should eq 0 }
  end
end

# The legacy watchdog is removed even on already-provisioned hosts.
describe file('/opt/relops-check_gw/check_gw.py') do
  it { should_not exist }
end

describe file('/lib/systemd/system/check_gw.timer') do
  it { should_not exist }
end

describe file('/lib/systemd/system/check_gw.service') do
  it { should_not exist }
end

describe service('check_gw.timer') do
  it { should_not be_enabled }
end
