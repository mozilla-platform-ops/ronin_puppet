require_relative 'spec_helper'

# This test suite checks for the presence of the generic worker checker script
describe file('/usr/local/bin/gw_checker.sh') do
  it { should exist }
end
