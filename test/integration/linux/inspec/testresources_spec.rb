require_relative 'spec_helper'

if os.family == 'ubuntu' && os.release == '18.04'
  describe package('python-testresources') do
    it { should be_installed }
  end
end

describe package('python3-testresources'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end
