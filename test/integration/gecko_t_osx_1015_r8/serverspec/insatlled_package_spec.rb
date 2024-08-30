require_relative 'spec_helper'

# # Check if Mercurial is installed with the correct version
# describe package('mercurial') do
#   it { should be_installed }
#   its('version') { should eq '6.4.5' }
# end

# # Check if Node.js is installed with the correct version
# describe package('nodejs') do
#   it { should be_installed }
#   its('version') { should eq '12.11.1' }
# end

# # Check if Python 2 is installed with the correct version
# describe package('python2') do
#   it { should be_installed }
#   its('version') { should eq '2.7.18' }
# end

# Check if Python 3 is installed with the correct version
describe package('python3') do
  it { should be_installed }
  its('version') { should eq '3.11.0' }
end
