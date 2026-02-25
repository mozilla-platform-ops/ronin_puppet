require_relative 'spec_helper'

describe 'Scroll bars always visible and save-to-cloud disabled' do
  describe command('defaults read /Library/Preferences/.GlobalPreferences AppleShowScrollBars') do
    its(:stdout) { should match(/^Always$/) }
  end

end
