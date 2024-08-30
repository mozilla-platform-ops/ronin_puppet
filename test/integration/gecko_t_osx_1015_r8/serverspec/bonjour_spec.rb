require_relative 'spec_helper'

# This test checks if Bonjour multicast advertisements are disabled
describe 'Bonjour multicast advertisements disabled' do
  # Check if the NoMulticastAdvertisements key is set correctly
  describe command('defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements') do
    its(:stdout) { should match(/^1$/) }
  end

  # Check if the mDNSResponder service is listed in any domain
  describe command('launchctl list | grep -E "(com.apple.mDNSResponder|mdnsresponder)"') do
    its(:stdout) { should match(/(com.apple.mDNSResponder|mdnsresponder)/) }
  end

  # Check if the mDNSResponder service is running or active
  describe command('launchctl print system/com.apple.mDNSResponder || launchctl print user/$(id -u)/com.apple.mDNSResponder || launchctl print gui/$(id -u)/com.apple.mDNSResponder') do
    its(:stdout) { should match(/state = running|state = active/) }
  end
end
