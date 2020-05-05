require_relative 'spec_helper'

describe 'users' do
  describe user('bclary') do
    it { should exist }
  end

  describe user('aerickson') do
    it { should exist }
  end

  describe user('jwatkins') do
    it { should exist }
  end

  describe user('dhouse') do
    it { should exist }
  end

  describe user('bitbar') do
    it { should exist }
  end
end

describe 'groups' do
  describe user('aerickson') do
    it { should belong_to_group 'wheel' }
  end

  describe user('bclary') do
    it { should belong_to_group 'wheel' }
  end

  describe user('jwatkins') do
    it { should belong_to_group 'wheel' }
  end
end

describe 'git repo' do
  describe command('cd /home/bitbar/mozilla-bitbar-devicepool && git status') do
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

describe command('python --version') do
  its(:exit_status) { should eq 0 }
end

describe command('/home/bitbar/mozilla-bitbar-devicepool/venv/bin/python --version') do
  its(:exit_status) { should eq 0 }
end

# last_started_alert stuff

describe command('python3 --version') do
  its(:exit_status) { should eq 0 }
end

describe command('/home/bitbar/android-tools/devicepool_last_started_alert/venv/bin/python --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Python 3/ }
end
