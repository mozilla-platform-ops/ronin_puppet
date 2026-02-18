require_relative 'spec_helper'

# Tests for macos_screenshot_helper: script, LaunchAgent plist, and loaded agent

describe file('/Users/cltbld/bin') do
  it { should be_directory }
  it { should be_owned_by 'cltbld' }
  it { should be_grouped_into 'staff' }
  it { should be_mode 755 }
end

describe file('/Users/cltbld/bin/capture-on-demand.sh') do
  it { should be_file }
  it { should be_owned_by 'cltbld' }
  it { should be_grouped_into 'staff' }
  it { should be_mode 755 }
  it { should be_executable }
end

describe file('/Users/cltbld/Library/LaunchAgents/com.mozilla.screencapture.plist') do
  it { should be_file }
  it { should be_owned_by 'cltbld' }
  it { should be_grouped_into 'staff' }
  it { should be_mode 644 }
  its(:content) { should match(/com\.mozilla\.screencapture/) }
  its(:content) { should match(/capture-on-demand\.sh/) }
end

describe 'Screenshot helper LaunchAgent loaded' do
  # cltbld uid is 555 on Darwin > 20 (macOS 12+)
  describe command('launchctl print gui/555/com.mozilla.screencapture') do
    its(:exit_status) { should eq 0 }
  end
end
