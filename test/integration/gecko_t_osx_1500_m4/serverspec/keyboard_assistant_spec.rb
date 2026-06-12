require_relative 'spec_helper'

# This test checks if the keyboard assistant suppression LaunchAgent is installed
describe 'keyboard assistant suppressed' do
  describe file('/Users/cltbld/Library/LaunchAgents/com.mozilla.suppress-keyboard-assistant.plist') do
    it { should be_file }
    it { should be_owned_by 'cltbld' }
  end
end
