require_relative 'spec_helper'

describe command('google-chrome --version') do
  its(:exit_status) { should eq 0 }
  # TODO: check version
  its(:stdout) { should match /Google Chrome/ }
end
