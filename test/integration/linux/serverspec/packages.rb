require_relative 'spec_helper'

describe package('ffmpeg'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end
