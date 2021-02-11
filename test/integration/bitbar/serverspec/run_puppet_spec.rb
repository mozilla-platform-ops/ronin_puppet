require_relative 'spec_helper'

describe file('/usr/local/bin/run-puppet.sh') do
  it { should exist }
  it { should be_file }
  it { should be_executable }
end
