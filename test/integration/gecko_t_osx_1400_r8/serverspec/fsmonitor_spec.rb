require_relative 'spec_helper'

describe file('/usr/local/bin/watchman') do
  it { should exist }
  it { should be_file }
end

describe file('/usr/local/bin/watchmanctl') do
  it { should exist }
  it { should be_file }
end
