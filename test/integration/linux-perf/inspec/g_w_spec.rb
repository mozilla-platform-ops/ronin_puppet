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

# check_gw
#

if os.family == 'debian' && (os.release.start_with?('18.04') or os.release.start_with?('22.04'))
  describe file('/opt/relops-check_gw/check_gw.py') do
    it { should exist }
    it { should be_executable }
  end

  describe service('check_gw.timer') do
    it { should be_enabled }
  end
elsif os.family == 'debian' && os.release.start_with?('24.04')
  # we don't install check_gw service on 24.04
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end
