require_relative 'spec_helper'

describe package('pulseaudio-utils'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe command('pactl --version') do
  its(:exit_status) { should eq 0 }
end
