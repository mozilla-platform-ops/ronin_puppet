require_relative 'spec_helper'

describe file('/opt/directory_cleaner') do
  it { should be_directory }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 755 }
end

describe file('/opt/directory_cleaner/configs') do
  it { should be_directory }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 755 }
end

describe file('/opt/directory_cleaner/configs/config.toml') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 644 }
end

describe file('/usr/local/bin/clean_before_reboot.sh') do
  it { should exist }
  it { should be_file }
  it { should be_mode 755 }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
end

describe file('/Library/LaunchDaemons/org.mozilla.cleanbeforereboot.plist') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 644 }
end
