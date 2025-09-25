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

describe file('/usr/local/bin/changeresolution.sh') do
  it { should exist }
end

# TODO: check more xdg/autostart files

describe file('/etc/xdg/autostart/gnome-software-service.desktop') do
  it { should exist }
end

# appearance: check ~cltbld files
describe file('/home/cltbld/.config/gnome-initial-setup-done') do
  it { should exist }
end

# verify the colord fix is in place
describe file('/etc/systemd/system/graphical.target') do
  it { should exist }
  its('content') { should match /After=multi-user.target rescue.service rescue.target display-manager.service colord.service/ }
  its('content') { should match /Wants=display-manager.service colord.service/ }
end
