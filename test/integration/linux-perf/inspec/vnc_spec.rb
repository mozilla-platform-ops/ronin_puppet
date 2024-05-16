require_relative 'spec_helper'

describe package('x11vnc'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

# TODO: check for config
