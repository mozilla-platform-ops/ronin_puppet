require_relative 'spec_helper'

describe 'directory_cleaner' do
  describe file('/usr/local/bin/directory_cleaner') do
    it { should exist }
    it { should be_executable }
  end

  describe file('/opt/directory_cleaner/configs/config.toml') do
    it { should exist }
    it { should be_file }
  end
end
