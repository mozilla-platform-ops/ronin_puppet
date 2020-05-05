require_relative 'spec_helper'

describe command('generic-worker --version') do
  its(:exit_status) { should eq 0 }
    # TODO: check version
  its(:stdout) { should match /generic-worker/ }
end

describe file('/etc/generic-worker.config') do
  it { should exist }
end

describe file('/usr/local/share/generic-worker/bugzilla-utils.sh') do
  it { should exist }
end

# TODO: check for tc-proxy, tc-w-r, liveproxy, etc