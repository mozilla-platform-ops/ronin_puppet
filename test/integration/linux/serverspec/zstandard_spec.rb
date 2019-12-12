require 'spec_helper.rb'

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