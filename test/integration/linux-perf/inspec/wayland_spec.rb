require_relative 'spec_helper'

if os.release.start_with?('24.04')
  wayland = input('wayland', value: false)

  describe file('/etc/gdm3/custom.conf') do
    its('content') { should match(/^WaylandEnable=#{wayland ? 'true' : 'false'}$/) }
    its('content') { should match(/^AutomaticLoginEnable = true$/) }
    its('content') { should match(/^AutomaticLogin = cltbld$/) }
  end

  if wayland
    describe package('gnome-remote-desktop') do
      it { should be_installed }
    end

    describe package('gir1.2-secret-1') do
      it { should be_installed }
    end

    describe file('/home/cltbld/.config/ronin-wayland-rdp') do
      it { should be_directory }
      its('mode') { should cmp '0700' }
      it { should be_owned_by 'cltbld' }
    end

    describe file('/etc/xdg/autostart/ronin-wayland-rdp.desktop') do
      its('content') { should include 'Exec=/usr/local/bin/configure-wayland-rdp' }
    end

    describe file('/usr/local/share/ronin-wayland/edid.bin') do
      its('sha256sum') { should eq 'de3ba650ba0e1f9852a1a832da2820c74da6db8cc4abd100bfe051dc3bb4f8bb' }
    end

    describe file('/etc/ronin-wayland-connector') do
      its('content') { should eq "HDMI-A-1\n" }
    end

    describe file('/etc/systemd/system/gdm3.service.d/10-headless-display.conf') do
      its('content') { should include 'Requires=ronin-wayland-display.service' }
      its('content') { should include 'After=ronin-wayland-display.service' }
    end

    describe service('ronin-wayland-display') do
      it { should be_enabled }
    end

    describe command('/bin/sh -n /usr/local/sbin/configure-headless-wayland') do
      its('exit_status') { should eq 0 }
    end

    describe ini('/var/lib/AccountsService/users/cltbld') do
      its(['User', 'Session']) { should eq 'ubuntu' }
      its(['User', 'SessionType']) { should eq 'wayland' }
    end

    describe file('/usr/share/wayland-sessions/ubuntu.desktop') do
      it { should exist }
    end

    describe file('/usr/local/bin/start-wayland-worker') do
      it { should be_executable }
      it { should be_owned_by 'root' }
    end

    describe file('/home/cltbld/.config/autostart/gnome-terminal.desktop') do
      its('content') { should include 'Exec=gnome-terminal -- /usr/local/bin/start-wayland-worker' }
    end

    describe command('/usr/bin/python3 -c "from gi.repository import Gio, GLib"') do
      its('exit_status') { should eq 0 }
    end

    # Docker has no physical compositor, but the worker must refuse an X11
    # fallback rather than silently accepting Wayland tasks in the wrong session.
    describe command('env -u WAYLAND_DISPLAY XDG_SESSION_TYPE=x11 /usr/local/bin/start-wayland-worker') do
      its('exit_status') { should eq 1 }
      its('stderr') { should include 'Worker requires a Wayland session' }
    end

    describe file('/etc/X11/xorg.conf.d/20-intel-primary.conf') do
      it { should_not exist }
    end
  end
end
