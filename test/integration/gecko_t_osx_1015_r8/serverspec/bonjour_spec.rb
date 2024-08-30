require_relative 'spec_helper'

# This test checks if Bonjour multicast advertisements are disabled
describe 'Bonjour multicast advertisements disabled' do
  # Check the macOS version and file settings
  describe command('defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements') do
    its(:stdout) { should match(/^1$/) }
  end

  # Ensure the mDNSResponder service is running and enabled
  describe service('com.apple.mDNSResponder') do
    it { should be_running }
    it { should be_enabled }
  end
end
