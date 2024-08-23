require_relative 'spec_helper'

# This test suite checks for the presence and properties of the Mercurial binary.
# Tests hard code the binary path so if it changes tests will fail
describe file('/Library/Frameworks/Python.framework/Versions/3.11/bin/hg') do
  it { should exist }
end
