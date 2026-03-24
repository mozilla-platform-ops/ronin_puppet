require_relative 'spec_helper'

# This test checks if the Screen Sharing (VNC) service is running
# Skipped in CI: GHA runners don't support screen sharing
describe service('com.apple.screensharing'), unless: ENV['CI'] do
  it { should be_running }
  it { should be_enabled }
end
