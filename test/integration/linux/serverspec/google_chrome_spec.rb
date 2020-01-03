require 'spec_helper.rb'

describe command('google-chrome --version') do
  its(:exit_status) { should eq 0 }
  # TODO: check version
  its(:stdout) { should match /Google Chrome/ }
end