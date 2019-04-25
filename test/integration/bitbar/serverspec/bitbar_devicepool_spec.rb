#----------------------------------------------------------------------
# instantiating testing requirements
#----------------------------------------------------------------------

if (!ENV['w_ssh'].nil? && ENV['w_ssh'] = 'true')
  begin
    require 'spec_helper.rb'
  rescue LoadError
  end
else
  begin
    require 'spec_helper.rb'
    set :backend, :exec
  rescue LoadError
  end
end

#  http://serverspec.org/resource_types.html

describe 'users' do
  describe user('bclary') do
    it { should exist }
  end

  describe user('aerickson') do
    it { should exist }
  end

  describe user('bitbar') do
    it { should exist }
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

describe 'reference-tests' do
  describe command('systemctl status zfasdf') do
    # code 4 is unknown
    its(:exit_status) { should eq 4 }
  end

  describe command('systemctl status ssh') do
    # code 0 is running
    its(:exit_status) { should eq 0 }
  end
end
