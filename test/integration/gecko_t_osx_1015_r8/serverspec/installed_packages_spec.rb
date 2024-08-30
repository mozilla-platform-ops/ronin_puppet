require_relative 'spec_helper'

# Check if Python 3 is installed with the correct version
describe command('python3 --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/Python 3\.11\.0/) }
end
