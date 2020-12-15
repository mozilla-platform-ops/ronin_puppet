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
  it { should exist }
  it { should be_executable }
end

describe file('/usr/local/share/generic-worker/bugzilla-utils.sh') do
  it { should exist }
  it { should be_executable }
end

describe file('/usr/local/bin/run-start-worker.sh') do
  it { should exist }
  it { should be_executable }
end

# config

describe file('/etc/start-worker.yml') do
  it { should exist }
end
