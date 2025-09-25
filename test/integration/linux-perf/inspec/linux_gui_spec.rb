require_relative 'spec_helper'

if os.family == 'debian' && (os.release.start_with?('18.04') or os.release.start_with?('22.04'))

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
    its('content') do
      should match(/After=multi-user.target rescue.service rescue.target display-manager.service colord.service/)
    end
    its('content') { should match(/Wants=display-manager.service colord.service/) }
  end
elsif os.family == 'debian' && os.release.start_with?('24.04')
  # packages
  describe package('xrestop') do
    it { should be_installed }
  end

  describe package('gnome-settings-daemon') do
    it { should be_installed }
  end

  describe package('gnome-session') do
    it { should be_installed }
  end

  describe package('gnome-shell') do
    it { should be_installed }
  end

  describe package('gnome-panel') do
    it { should be_installed }
  end

  describe package('gnome-initial-setup') do
    it { should_not be_installed }
  end

  # files
  describe file('/etc/X11/Xwrapper.config') do
    it { should exist }
  end

  describe file('/etc/X11/edid.bin') do
    it { should exist }
  end

  describe file('/etc/xdg/autostart/org.gnome.DejaDup.Monitor.desktop') do
    it { should exist }
  end

  describe file('/etc/xdg/autostart/update-notifier.desktop') do
    it { should exist }
  end

  describe file('/etc/xdg/autostart/gnome-software-service.desktop') do
    it { should exist }
  end

  describe file('/usr/share/X11/xorg.conf.d/99-serverflags.conf') do
    it { should exist }
  end

  describe file('/usr/share/X11/xorg.conf.d/50-display.conf') do
    it { should exist }
  end

  describe file('/home/cltbld/.fonts.conf') do
    it { should exist }
  end

  describe file('/home/cltbld/.pip/pip.conf') do
    it { should exist }
  end

  describe file('/home/cltbld/.config/pulse/client.conf') do
    it { should_not exist }
  end

  describe file('/etc/gdm3/custom.conf') do
    it { should exist }
  end

  # directories
  describe file('/home/cltbld/.pip') do
    it { should be_directory }
  end

  describe file('/home/cltbld/.config/pulse') do
    it { should be_directory }
  end

  describe file('/home/cltbld/.config/systemd') do
    it { should be_directory }
  end

  describe file('/home/cltbld/.config/systemd/user') do
    it { should be_directory }
  end

  # services
  describe service('gdm3') do
    it { should be_enabled }
    # won't be running on test systems yet
    # it { should be_running }
  end

  # nvidia packages should be absent
  describe command('dpkg -l | grep nvidia-') do
    its(:stdout) { should eq "" }
  end

  # systemd-networkd should be disabled
  describe service('systemd-networkd') do
    it { should_not be_enabled }
  end

  # apparmor profile should be present
  describe file('/etc/apparmor.d/firefox-local') do
    it { should exist }
  end
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match(/NONO/) }
  end
end
