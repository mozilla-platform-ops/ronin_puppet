require 'spec_helper.rb'

describe command('generic-worker --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /generic-worker/ }
end