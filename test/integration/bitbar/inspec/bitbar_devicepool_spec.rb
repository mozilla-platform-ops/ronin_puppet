require_relative 'spec_helper'

describe 'users' do
  describe user('aerickson') do
    it { should exist }
    %w(aerickson wheel).each do |group|
      its('groups') { should include group }
    end
  end

  describe user('mgoossens') do
    it { should exist }
    %w(mgoossens wheel).each do |group|
      its('groups') { should include group }
    end
  end

  describe user('bitbar') do
    it { should exist }
  end
end

describe 'git repo' do
  describe bash("sudo -u bitbar bash -c 'cd /home/bitbar/mozilla-bitbar-devicepool && git status'") do
    its(:exit_status) { should eq 0 }
  end
end

describe 'service' do
  # service:is_installed is windows only
  describe command('systemctl status bitbar') do
    # code 3 is loaded, but not running
    its(:exit_status) { should eq 3 }
  end
end

# 2204 doesn't have python(2)
if os.family == 'debian' && os.release == '18.04'
  describe command('python --version') do
    its(:exit_status) { should eq 0 }
  end
  # TODO: else with echo stating we're not testing for this?
end

describe command('/home/bitbar/mozilla-bitbar-devicepool/venv/bin/python --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Python 3/ }
end

# last_started_alert stuff

describe command('python3 --version') do
  its(:exit_status) { should eq 0 }
end

describe command('/home/bitbar/android-tools/devicepool_last_started_alert/venv/bin/python --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Python 3/ }
end
