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

# 18.04 is pinned to an older version provided by s3
# latest updates are too new for 18.04
if os.family == 'debian' && os.release == '18.04'
  describe command('google-chrome-stable --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Google Chrome/ }
  end
end
