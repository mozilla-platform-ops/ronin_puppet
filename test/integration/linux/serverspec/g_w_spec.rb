require 'spec_helper.rb'

describe command('generic-worker --version') do
  its(:exit_status) { should eq 0 }
    # TODO: check version
  its(:stdout) { should match /generic-worker/ }
end

# TODO: check for tc-proxy, tc-w-r, liveproxy, etc