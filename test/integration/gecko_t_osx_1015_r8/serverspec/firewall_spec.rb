require_relative 'spec_helper'

describe 'macOS Application Layer Firewall disabled' do
  describe command('/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate') do
    its(:stdout) { should match(/disabled/) }
    its(:exit_status) { should eq 0 }
  end
end
