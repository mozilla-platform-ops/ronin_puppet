require_relative 'spec_helper'

if os[:family] == 'ubuntu' && !input('wayland', value: false)
  describe package('x11vnc') do
    it { should be_installed }
  end
end

# TODO: check for config
