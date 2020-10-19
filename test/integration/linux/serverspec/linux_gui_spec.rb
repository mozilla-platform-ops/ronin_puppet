require_relative 'spec_helper'

# packages

describe package('xrestop') do
  it { should be_installed }
end

describe package('gnome-settings-daemon') do
  it { should be_installed }
end

# files

describe file('/etc/X11/xorg.conf') do
  it { should exist }
end

describe file('/lib/systemd/system/x11.service') do
  it { should exist }
end

describe file('/lib/systemd/system/Xsession.service') do
  it { should exist }
end

describe file('/home/cltbld/.xsessionrc') do
  it { should exist }
end

describe file('/etc/X11/Xwrapper.config') do
  it { should exist }
end

describe file('/etc/X11/edid.bin') do
  it { should exist }
end

# TODO: check more xdg/autostart files

describe file('/etc/xdg/autostart/gnome-software-service.desktop') do
  it { should exist }
end
