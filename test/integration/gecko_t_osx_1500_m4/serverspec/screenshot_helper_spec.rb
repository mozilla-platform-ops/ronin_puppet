require_relative 'spec_helper'

describe file('/Users/cltbld/bin') do
  it { should be_directory }
  it { should be_owned_by 'cltbld' }
  it { should be_grouped_into 'staff' }
  it { should be_mode 755 }
end

describe file('/Users/cltbld/bin/capture-on-demand.sh') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'cltbld' }
  it { should be_grouped_into 'staff' }
  it { should be_mode 755 }
end

describe file('/Users/cltbld/Library/LaunchAgents/com.mozilla.screencapture.plist') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'cltbld' }
  it { should be_grouped_into 'staff' }
  it { should be_mode 644 }
end
