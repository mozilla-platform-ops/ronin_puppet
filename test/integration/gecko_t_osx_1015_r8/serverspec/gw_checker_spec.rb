require_relative 'spec_helper'

# This test suite checks for the presence of the generic worker checker script
describe file('/usr/local/bin/gw_checker.sh') do
  it { should exist }
  it { should be_executable.by('owner') }
  it { should be_executable.by('group') }
  it { should be_executable.by('others') }
end

# Experimental
# This test checks if the root crontab contains the gw_checker.sh entry
describe command('crontab -l -u root') do
  its(:stdout) { should match(%r{^\*/30 \* \* \* \* /usr/local/bin/gw_checker.sh}) }
end
