require_relative 'spec_helper'

describe file('/etc/sudoers') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 440 }
end

describe file('/etc/sudoers.d') do
  it { should_not exist }
end
