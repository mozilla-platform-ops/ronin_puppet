require_relative 'spec_helper'

describe command('pip list | grep zstandard') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /zstandard/ }
end

describe command('pip3 list | grep zstandard') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /zstandard/ }
end

describe command('zstd') do
  its(:exit_status) { should eq 1 }
  its(:stderr) { should match /Usage/ }
end

describe command('zstd --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should contain "zstd command line interface" }
end
