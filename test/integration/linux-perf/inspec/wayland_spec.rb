require_relative 'spec_helper'

if ENV['MOZILLA_WAYLAND'] == '1'
  describe file('/etc/xdg/weston/weston.ini') do
    it { should exist }
    its('content') { should match /shell=desktop-shell/ }
  end
else
  describe file('/etc/xdg/weston/weston.ini') do
    it { should_not exist }
  end
end
