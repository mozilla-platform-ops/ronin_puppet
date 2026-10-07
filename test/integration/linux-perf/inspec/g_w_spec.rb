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

worker_engine = file('/etc/taskcluster-worker-engine').content.strip

describe file('/etc/taskcluster-worker-engine') do
  it { should exist }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
  its('mode') { should cmp '0644' }
  its('content') { should match /\A(simple|multiuser-static)\n\z/ }
end

if worker_engine == 'multiuser-static'
  describe file('/etc/systemd/system/generic-worker.service') do
    it { should exist }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0644' }
    its('content') { should match %r{WorkingDirectory=/var/lib/generic-worker} }
    its('content') { should match %r{ExecStart=/usr/local/bin/run-generic-worker-root\.sh /etc/start-worker\.yml} }
  end

  describe service('generic-worker.service') do
    it { should be_enabled }
  end

  describe file('/usr/local/bin/run-generic-worker-root.sh') do
    it { should exist }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0700' }
  end

  describe file('/var/lib/generic-worker') do
    it { should be_directory }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0700' }
  end

  describe file('/var/lib/generic-worker/next-task-user.json') do
    it { should exist }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0600' }
    its('content') { should match /"name": "cltbld"/ }
  end

  describe file('/home/cltbld/.config/autostart/gnome-terminal.desktop') do
    it { should_not exist }
  end

  describe file('/etc/start-worker.yml') do
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'root' }
    its('mode') { should cmp '0600' }
    its('content') { should match %r{configPath: /var/lib/generic-worker/generic-worker\.config} }
  end
elsif worker_engine == 'simple'
  describe file('/etc/systemd/system/generic-worker.service') do
    it { should_not exist }
  end

  describe file('/usr/local/bin/run-generic-worker-root.sh') do
    it { should_not exist }
  end

  describe file('/home/cltbld/.config/autostart/gnome-terminal.desktop') do
    it { should exist }
  end

  describe file('/etc/start-worker.yml') do
    its('mode') { should cmp '0644' }
    its('content') { should match %r{configPath: /home/cltbld/generic-worker\.config} }
  end
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
