require_relative 'spec_helper'

# This test checks if the keyboard assistant is suppressed by verifying
# the keyboardtype plist has the expected dict entry
describe 'keyboard assistant suppressed' do
  describe command('defaults read /Library/Preferences/com.apple.keyboardtype keyboardtype') do
    its(:stdout) { should match(/"4101-5341-33" = 40/) }
  end
end
