require_relative 'spec_helper'

describe package('ffmpeg'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe file('/usr/local/bin/tooltool.py') do
  it { should exist }
  it { should be_executable }
end
