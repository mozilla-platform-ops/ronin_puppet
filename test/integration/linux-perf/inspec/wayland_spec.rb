require_relative 'spec_helper'

if os.release.start_with?('24.04')
  wayland = input('wayland', value: false)

  describe file('/etc/gdm3/custom.conf') do
    its('content') { should match(/^WaylandEnable=#{wayland ? 'true' : 'false'}$/) }
    its('content') { should match(/^AutomaticLoginEnable = true$/) }
    its('content') { should match(/^AutomaticLogin = cltbld$/) }
  end

  if wayland
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
