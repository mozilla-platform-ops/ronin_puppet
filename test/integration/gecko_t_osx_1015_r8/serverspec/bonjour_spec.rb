require_relative 'spec_helper'

# This test checks if Bonjour multicast advertisements are disabled
describe 'Bonjour multicast advertisements disabled' do
  # Check the macOS version and file settings
  describe command('defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements') do
    its(:stdout) { should match(/^1$/) }
  end

  # Check if the mDNSResponder service is running
  describe command('launchctl list | grep com.apple.mDNSResponder') do
    its(:stdout) { should match(/com.apple.mDNSResponder/) }
  end

  # Alternatively, use a command to check if the service is active
  describe command('launchctl print system/com.apple.mDNSResponder | grep -E "state = running|state = active"') do
    its(:exit_status) { should eq 0 }
  end
end
