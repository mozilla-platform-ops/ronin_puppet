require_relative 'spec_helper'

# This test suite checks for the presence and properties of the Mercurial binary.
# Tests hard code the binary path so if it changes tests will fail
describe 'mercurial' do
    describe file('/usr/local/bin/hg') do
      it { should exist }
      it { should be_file }
    end
  end
