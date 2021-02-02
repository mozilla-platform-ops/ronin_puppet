require_relative 'spec_helper'

describe file('/usr/local/bin/run-puppet.sh') do
  it { should exist }
  # its(:content) { should match /bclary\:.*\:\/usr\/sbin\/nologin/ }
end
