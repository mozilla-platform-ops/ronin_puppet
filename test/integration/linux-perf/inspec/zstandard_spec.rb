require_relative 'spec_helper'

# no more py2
#
# describe bash('pip list | grep zstandard') do
#   its('exit_status') { should eq 0 }
#   its('stdout') { should match /zstandard/ }
# end

describe bash('pip3 list | grep zstandard') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /zstandard/ }
end

describe bash('zstd --version') do
  its('exit_status') { should eq 0 }
  its('stdout') { should match /zstd command line interface|Zstandard CLI/ }
end
