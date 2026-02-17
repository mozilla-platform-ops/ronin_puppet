require_relative 'spec_helper'

# This test checks if the Screen Sharing (VNC) service is running
describe service('com.apple.screensharing') do
  it { should be_running }
  it { should be_enabled }
end
