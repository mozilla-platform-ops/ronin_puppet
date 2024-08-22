require_relative 'spec_helper'

if os.family == 'debian' && os.release == '24.04'
  describe command('google-chrome-stable --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Google Chrome/ }
  end
end

if os.family == 'debian' && os.release == '22.04'
  describe command('google-chrome-stable --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Google Chrome/ }
  end
end

# 18.04 is busted, due to new package requirement that's not available
if os.family == 'debian' && os.release == '18.04'
  # pass
end
