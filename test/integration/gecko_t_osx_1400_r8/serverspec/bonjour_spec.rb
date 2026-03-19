require_relative 'spec_helper'

# This test checks if the NoMulticastAdvertisements key is set to 1 in the mDNSResponder preferences
describe 'Bonjour multicast advertisements disabled' do
  describe command('defaults read /Library/Preferences/com.apple.mDNSResponder NoMulticastAdvertisements') do
    its(:stdout) { should match(/^1$/) }
  end
end
