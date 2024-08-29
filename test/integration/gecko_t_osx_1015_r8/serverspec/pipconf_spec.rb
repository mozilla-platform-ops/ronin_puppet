require_relative 'spec_helper'

# This test suite checks for the presence and properties of the Mercurial binary.
# Tests hard code the binary path so if it changes tests will fail
describe file('/Library/Application Support/pip/pip.conf') do
  it { should exist }
end
