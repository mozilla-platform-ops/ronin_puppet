# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Ensures the docker/lima/colima Homebrew formulae are present and, critically,
# makes Colima reboot-persistent.
#
# Homebrew itself is NOT installed here (the host is bootstrapped once with brew
# preinstalled at the Apple-Silicon path /opt/homebrew, admin-owned). We assert
# it is present and fail with a clear message otherwise.
#
# Reboot persistence: the original design started Colima with a one-shot
# `exec { unless colima status | grep running }`, which only fires during a
# puppet apply. On a registry host with no puppet cron that means a reboot
# leaves Colima (and therefore the whole OCI registry the tester fleet depends
# on) DOWN until a human runs `colima start`. Instead we install a system
# LaunchDaemon that runs an idempotent ensure-script at boot (RunAtLoad) and on
# an interval (self-heal). Combined with the registry container's
# `--restart=always`, the registry comes back on its own after any reboot.
#
# Colima runs headless Linux VMs (no graphical framebuffer), so unlike Tart it
# does not require an Aqua GUI session — the system LaunchDaemon starts it as
# `admin` without a login. `colima.autologin_kcpassword` is offered as an
# optional safety net (empty = unmanaged); populate it via vault/hiera only if a
# host turns out to need a live console session.
class roles_profiles::profiles::colima_docker {
  $user            = lookup('docker.user',                  String,  'first', 'admin')
  $package_name    = lookup('docker.package_name',          String,  'first', 'docker')
  $cpu             = lookup('docker.cpu',                    Integer, 'first', 8)
  $memory          = lookup('docker.memory',                Integer, 'first', 8)
  $disk_size       = lookup('docker.disk_size',             Integer, 'first', 200)
  $ensure_interval = lookup('docker.colima_ensure_interval', Integer, 'first', 300)

  $brew_path = '/opt/homebrew/bin/brew'
  $home      = "/Users/${user}"

  # Homebrew must be preinstalled. Fail loudly (once, at compile-of-exec time)
  # rather than silently proceeding to a broken `brew install`.
  exec { 'assert_homebrew_present':
    command => "/bin/echo 'Homebrew missing at ${brew_path}; bootstrap this host with brew before applying oci_registry_host' >&2 && exit 1",
    unless  => "/bin/test -x ${brew_path}",
    path    => ['/usr/bin', '/bin'],
  }

  # Ensure docker + lima + colima formulae (idempotent; no-op once present).
  exec { 'install_docker_colima':
    command   => "/usr/bin/su - ${user} -c '${brew_path} install ${package_name} lima colima || true'",
    unless    => "/usr/bin/su - ${user} -c '${brew_path} list --formula | grep -E \"(${package_name}|lima|colima)\"'",
    path      => ['/opt/homebrew/bin', '/usr/local/bin', '/usr/bin', '/bin'],
    timeout   => 0,
    logoutput => true,
    require   => Exec['assert_homebrew_present'],
  }

  exec { 'verify_docker_colima':
    command => "/opt/homebrew/bin/docker --version && /usr/bin/su - ${user} -c '/opt/homebrew/bin/colima version'",
    unless  => "/opt/homebrew/bin/docker --version >/dev/null 2>&1 && /usr/bin/su - ${user} -c '/opt/homebrew/bin/colima version >/dev/null 2>&1'",
    path    => ['/opt/homebrew/bin', '/usr/local/bin', '/usr/bin', '/bin'],
    require => Exec['install_docker_colima'],
  }

  # Idempotent ensure-script: starts Colima only if it is not already running,
  # reusing the persisted profile so it never resizes an existing VM.
  file { '/usr/local/bin/colima-ensure.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    content => epp('roles_profiles/oci_registry/colima-ensure.sh.epp', {
      user      => $user,
      cpu       => $cpu,
      memory    => $memory,
      disk_size => $disk_size,
    }),
    require => Exec['verify_docker_colima'],
  }

  # System LaunchDaemon (runs as root, drives colima via `su - ${user}`): starts
  # Colima at boot (RunAtLoad) and self-heals on an interval. Loads headlessly,
  # no console session required.
  file { '/Library/LaunchDaemons/com.mozilla.colima.plist':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('roles_profiles/oci_registry/com.mozilla.colima.plist.epp', {
      ensure_interval => $ensure_interval,
    }),
    require => File['/usr/local/bin/colima-ensure.sh'],
    notify  => Exec['load_colima_daemon'],
  }

  exec { 'load_colima_daemon':
    command     => '/bin/bash -c \'launchctl bootout system /Library/LaunchDaemons/com.mozilla.colima.plist 2>/dev/null || true; launchctl bootstrap system /Library/LaunchDaemons/com.mozilla.colima.plist\'',
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    require     => File['/Library/LaunchDaemons/com.mozilla.colima.plist'],
  }

  # Optional autologin safety net (default off). Colima is headless so this is
  # normally unnecessary; populate colima.autologin_kcpassword only if needed.
  $autologin_kcpassword = lookup('colima.autologin_kcpassword', String, 'first', '')
  if $autologin_kcpassword != '' {
    class { 'macos_utils::autologin_user':
      user       => $user,
      kcpassword => $autologin_kcpassword,
    }
  }
}
