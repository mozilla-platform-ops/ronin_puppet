require_relative 'spec_helper'

# files

describe file('/lib/systemd/system/puppet.service') do
  it { should exist }
end

describe file('/usr/local/bin/run-puppet.sh') do
  it { should exist }
  it { should be_executable }
end
