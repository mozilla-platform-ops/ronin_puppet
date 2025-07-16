require_relative 'spec_helper'

# This test checks if the system timezone is set to GMT
describe 'System Timezone' do
  describe command('sudo systemsetup -gettimezone') do
    its(:stdout) { should match(/GMT/) }
  end
end
