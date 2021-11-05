require_relative 'spec_helper'

describe command('google-chrome-stable --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Google Chrome/ }
end
