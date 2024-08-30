require_relative 'spec_helper'

# This test checks if the Xcode Command Line Tools are installed
describe command('xcode-select -p') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(%r{/Library/Developer/CommandLineTools}) }
end
