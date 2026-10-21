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

describe file('/etc/start-worker.yml') do
  it { should exist }
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
