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

The worker launches directly from GNOME autostart without a terminal window.
View its output with `journalctl -b -t run-start-worker -t generic-worker`.

## Headless Intel display

These workers have no attached monitor or EDID adapter. On `ms001`, an Intel
P580 HDMI-A-1 output successfully completed a real 1600x1200, 60 Hz modeset
using the repository EDID through the kernel's runtime override interfaces.
The Matrox management VGA output was left connected during that experiment.
Native GNOME Wayland, Intel P580 OpenGL rendering, RDP authentication and screen
sharing, and automatic desktop/RDP recovery after reboot are verified on ms001.
Full worker-role convergence and a real Talos task remain outstanding.

The `gui_wayland` profile passes `headless_connector => 'HDMI-A-1'` directly.
`ronin-wayland-display.service` loads the EDID and forces that Intel output on
before GDM starts. It finds the Intel PCI device rather than assuming a DRM
card number. A GDM dependency prevents login if headless setup fails. A udev
rule marks Intel as Mutter's preferred primary GPU. No GRUB or initramfs
changes are required.

The launcher selects the configured connector explicitly and disables other
outputs for the worker session. The management VGA output therefore may not
show the worker desktop; use RDP to view the test session.

Inspect the hardware and startup service with:

```bash
ls -l /sys/class/drm/
lspci -nn | grep -Ei 'VGA|Display'
systemctl status ronin-wayland-display
journalctl -b -u ronin-wayland-display --no-pager
```

## RDP desktop sharing

The Wayland role uses GNOME Remote Desktop to share the existing `cltbld`
session. RDP is accepted for this rollout; the role no longer installs the X11
VNC profile. The helper runs after graphical autologin, sets mirror-primary
mode at port 3389, and starts the user desktop-sharing service. It does not
configure GNOME's system remote-login service.

Setup disables session idle blanking and idle dimming. Disabling screen locking
alone is insufficient: GNOME's idle screen shield can still reject RDP sessions
with `Session creation inhibited` after five minutes without input.

Each host generates its own username/password file and self-signed TLS
certificate in `/home/cltbld/.config/ronin-wayland-rdp/` (directory mode 0700,
private files mode 0600). Credentials persist across logins and can be retrieved
by an operator with sudo on the host. Passwords are never printed by setup or
included in process arguments. Desktop sharing stores them in the user's GNOME
keyring. A user-service drop-in initializes and unlocks the login keyring with the
per-host password supplied through stdin. Setup preserves an existing differently
protected keyring and reports failure if it cannot unlock it.

An actual FreeRDP client authenticated and captured the GNOME desktop after
reboot. Use an RDP client, optionally through an SSH tunnel:

```bash
ssh -L 13389:localhost:3389 -l relops t-linux64-ms-001.test.releng.mdc1.mozilla.com
# Connect the RDP client to localhost:13389.
```

Check the generated credentials locally on the host with sudo, and verify the
certificate fingerprint before accepting it in the client. Disconnect the RDP
viewer before performance measurements.

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
without starting the worker. Inspect the user-session journal and compositor state
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
