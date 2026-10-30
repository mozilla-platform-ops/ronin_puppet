# Ubuntu 24.04 Wayland hardware canary

The role is `gecko_t_linux_2404_talos_wayland`; its worker pool is
`releng-hardware/gecko-t-linux-talos-2404-wayland`.

The desktop uses GDM autologin and Ubuntu's GNOME Wayland session. Common
desktop settings, fonts, browser AppArmor profiles, and networking setup are
shared with the Ubuntu 24.04 X11 role. Xorg display configuration is excluded.
The worker launcher refuses an X11 fallback and configures one physical output
at 1600x1200, approximately 60 Hz, scale 1 before starting generic-worker. Other
outputs are disabled for this session. The selected mode must be advertised by
the kernel's DRM connector; Xorg modelines do not configure Wayland.

## Headless hardware status

These workers have no attached monitor or EDID adapter. Headless display
bringup is still pending validation on the physical canary; the session and
launcher changes alone do not make this role ready for those hosts.

The repository already contains `modules/linux_gui/files/edid.bin`, a valid
128-byte EDID with a preferred 1600x1200 mode at 60 Hz. A candidate approach is
to install it as kernel firmware, include it in the initramfs, and configure
`drm.edid_firmware=CONNECTOR:edid/ronin-1600x1200.bin` together with
`video=CONNECTOR:1600x1200@60e`. Linux supports
[EDID firmware overrides](https://docs.kernel.org/admin-guide/edid.html) and
[forcing a DRM output on](https://docs.kernel.org/fb/modedb.html).

This is a proposed hardware experiment, not configuration currently installed
by this role. Identify an output belonging to the Intel GPU first; do not assume
that `card0`, a BMC VGA output, or a particular connector name is correct:

```bash
ls -l /sys/class/drm/
lspci -nn | grep -Ei 'VGA|Display'
```

Confirm that the Intel driver can actually activate the selected output without
a physical sink before automating boot parameters. Successful firmware loading
alone does not prove the output can be used by GNOME. If the GPU exposes no
usable physical connector, a different compositor/virtual-output approach will
need evaluation, including its effects on Talos rendering and presentation.

Display setup uses [Mutter 46's DisplayConfig interface](https://github.com/GNOME/mutter/blob/46.0/data/dbus-interfaces/org.gnome.Mutter.DisplayConfig.xml).
Docker validates configuration and startup refusal, but cannot validate the
physical GPU, compositor, or display mode.

## Fresh physical host

Install Ubuntu 24.04 and use `provisioners/linux/deliver_linux.sh` to deliver the
bootstrap and Vault data for the Wayland role. Vault must contain
`generic_worker.gecko_t_linux_talos_2404_wayland` credentials for the pool above.
The development branch must be available in the remote repository first.

On the host, as root, create `/etc/puppet/ronin_settings` with the actual remote
repository and development branch. These settings persist across boot-time
Puppet runs; setting the branch only for bootstrap is insufficient.

```bash
install -d -m 0755 /etc/puppet
cat >/etc/puppet/ronin_settings <<'EOF'
PUPPET_REPO='https://github.com/mozilla-platform-ops/ronin_puppet.git'
PUPPET_BRANCH='20261030-2404_wayland_errata'
EOF
chmod 0640 /etc/puppet/ronin_settings
printf '%s\n' gecko_t_linux_2404_talos_wayland >/etc/puppet_role

# The initial bootstrap reads its environment rather than ronin_settings.
. /etc/puppet/ronin_settings
export PUPPET_REPO PUPPET_BRANCH
bash /tmp/bootstrap.sh -l /var/log/bootstrap-wayland.log
```

Use the bootstrap path printed by `deliver_linux.sh` if it differs. After a
successful converge, reboot and check:

```bash
systemctl --failed
systemctl get-default
systemctl status gdm3 run-puppet
loginctl list-sessions
# Replace SESSION with cltbld's graphical session ID:
loginctl show-session SESSION -p Name -p Type -p State
/usr/local/bin/gwhc
journalctl -b -t run-start-worker -t generic-worker --no-pager
```

The graphical session must belong to `cltbld`, have `Type=wayland`, and be
active. From a terminal in that session, inspect the compositor configuration:

```bash
gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
  --object-path /org/gnome/Mutter/DisplayConfig \
  --method org.gnome.Mutter.DisplayConfig.GetCurrentState
```

Confirm one active physical output at 1600x1200, approximately 60 Hz, scale 1,
and GPU acceleration with the expected Intel GPU. Run a real Wayland Talos task;
check Firefox's window protocol and graphics information in its task artifacts.
Then confirm that the worker completes its task, reboots, converges from the
development branch, and returns to the same session and pool. Repeat a cold boot
and a second Puppet converge to check recovery and idempotence.

GDM may fall back to X11 if the hardware or driver cannot support Wayland. In
that case, or if the required display mode is unavailable, the launcher exits
without starting the worker. Inspect the autostart terminal and compositor state
before changing display settings. Remote graphical access through the existing
X11 VNC service is not a Wayland validation method; use the physical console/KVM.

## Repository validation

```bash
python3 -m unittest discover -s test -p test_wayland_worker.py
./bin/kitchen_docker converge linux-perf-wayland-ubuntu-2404
./bin/kitchen_docker verify linux-perf-wayland-ubuntu-2404
./bin/kitchen_docker converge linux-perf-ubuntu-2404
./bin/kitchen_docker verify linux-perf-ubuntu-2404
```
