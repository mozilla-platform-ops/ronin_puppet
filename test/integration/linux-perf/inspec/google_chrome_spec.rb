require_relative 'spec_helper'

# Test for Google Chrome installation on all supported Ubuntu versions
if os.family == 'debian' && ['18.04', '22.04', '24.04'].include?(os.release)
  describe command('google-chrome-stable --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Google Chrome/ }
  end
end
