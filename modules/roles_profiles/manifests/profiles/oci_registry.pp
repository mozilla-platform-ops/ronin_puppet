# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Runs the local, insecure OCI registry that serves Tart VM images to the
# tester fleet, as a NATIVE macOS process (no Docker/Colima).
#
# The distribution `registry` (v3) binary is a static Go HTTP server. We fetch
# it from the ronin package bucket (verified by sha256), drop a filesystem-
# backed config, and run it under a launchd KeepAlive daemon. Because it is a
# plain native process, it starts at boot and restarts on crash with no VM,
# vsock, or GUI-session dependency — the reboot-resilience the Colima setup
# never had.
#
# Resilience features:
#   * launchd RunAtLoad + KeepAlive  -> survives reboot and crash on its own.
#   * daily maintenance daemon        -> prune disposable tags + native
#                                        `registry garbage-collect` so storage
#                                        does not grow without bound.
#   * periodic health/disk daemon     -> verify /v2/ + storage headroom, write a
#                                        status file for dashboards, alert.
class roles_profiles::profiles::oci_registry {
  $version        = lookup('oci_registry.version',        String,  'first', 'v3.0.0')
  $binary_url     = lookup('oci_registry.binary_url',     String,  'first')
  $binary_sha256  = lookup('oci_registry.binary_sha256',  String,  'first')
  $registry_dir   = lookup('oci_registry.registry_dir',   String,  'first', '/Users/admin/registry-data')
  $registry_port  = lookup('oci_registry.registry_port',  Integer, 'first', 5000)
  $user           = lookup('oci_registry.user',           String,  'first', 'admin')
  $http_secret    = lookup('oci_registry.http_secret',    String,  'first', 'change-me-single-node')
  $keep_prod_shas = lookup('oci_registry.keep_prod_shas', Integer, 'first', 10)
  $prune_pr_shas  = lookup('oci_registry.prune_pr_shas',  Boolean, 'first', true)
  $maint_hour     = lookup('oci_registry.maintenance_hour', Integer, 'first', 9)
  $disk_threshold = lookup('oci_registry.disk_threshold_pct', Integer, 'first', 85)
  $health_interval = lookup('oci_registry.health_interval', Integer, 'first', 300)
  $alert_email    = lookup('oci_registry.alert_email',    String,  'first', 'releng-ci-alerts@mozilla.com')
  $smtp_relay     = lookup('oci_registry.smtp_relay',     String,  'first', 'smtp1.mail.mdc1.mozilla.com')

  # Push authentication (Bug 2049579 rec #4). When oci_registry_push_htpasswd is
  # set (an htpasswd file body, delivered via a SECRET override — never
  # committed; ronin_puppet is public), an nginx reverse proxy fronts the
  # registry and requires basic auth for writes (PUT/POST/PATCH/DELETE) while
  # leaving pulls (GET/HEAD) anonymous, so only the holder of the push
  # credential can publish images. The registry then binds loopback only and
  # nginx owns the public port. Empty (default) = no proxy, registry binds the
  # public port directly (open push, the pre-hardening behaviour).
  #
  # NB: this is a TOP-LEVEL key, deliberately NOT nested under the oci_registry
  # hash. Secrets live in vault.yaml (the highest-priority hiera layer) and
  # lookups here use 'first' (no deep merge); a partial `oci_registry:` hash in
  # vault.yaml would shadow the whole role-data `oci_registry` hash (hiding
  # binary_url etc.). A distinct top-level key avoids that collision.
  $push_htpasswd = lookup('oci_registry_push_htpasswd', String,  'first', '')
  $internal_port = lookup('oci_registry.internal_port', Integer, 'first', 5001)
  $push_auth     = $push_htpasswd != ''
  $listen_addr   = $push_auth ? { true => "127.0.0.1:${internal_port}", default => "0.0.0.0:${registry_port}" }
  # Host-local tooling (maintenance, verify) talks straight to the registry,
  # bypassing the auth proxy: internal port when the proxy is on, public port
  # otherwise.
  $local_port    = $push_auth ? { true => $internal_port, default => $registry_port }

  $bin_path    = '/usr/local/bin/registry'
  $config_dir  = '/usr/local/etc/oci-registry'
  $config_path = "${config_dir}/config.yml"
  $log_path    = '/var/log/oci-registry.log'
  $daemon      = '/Library/LaunchDaemons/com.mozilla.oci-registry.plist'

  # --- Retire the superseded Colima registry stack -------------------------
  # This host used to run com.mozilla.colima (+ a registry container). Boot it
  # out and remove the plist so it cannot start Colima at the next reboot.
  exec { 'bootout_colima_daemon':
    command => '/bin/bash -c \'launchctl bootout system /Library/LaunchDaemons/com.mozilla.colima.plist 2>/dev/null || true\'',
    onlyif  => '/bin/test -f /Library/LaunchDaemons/com.mozilla.colima.plist',
    path    => ['/bin', '/usr/bin'],
  }
  file { ['/Library/LaunchDaemons/com.mozilla.colima.plist', '/usr/local/bin/colima-ensure.sh']:
    ensure  => absent,
    require => Exec['bootout_colima_daemon'],
  }

  # --- Native registry binary (fetched + sha256-verified) ------------------
  file { $registry_dir:
    ensure => directory,
  }

  exec { 'download_registry_binary':
    command => "/bin/bash -c 'set -e; /usr/bin/curl -fsSL -o ${bin_path} \"${binary_url}\"; /bin/chmod 0755 ${bin_path}; echo \"${binary_sha256}  ${bin_path}\" | /usr/bin/shasum -a 256 -c -'",
    unless  => "/bin/test -x ${bin_path} && /usr/bin/shasum -a 256 ${bin_path} | /usr/bin/grep -q '${binary_sha256}'",
    path    => ['/usr/bin', '/bin'],
    timeout => 600,
  }

  file { $config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  file { $config_path:
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('roles_profiles/oci_registry/config.yml.epp', {
      registry_dir => $registry_dir,
      listen_addr  => $listen_addr,
      http_secret  => $http_secret,
    }),
    notify  => Exec['load_oci_registry_daemon'],
  }

  # launchd writes here as $user, so pre-create it owned by $user.
  file { $log_path:
    ensure => file,
    owner  => $user,
    group  => 'staff',
    mode   => '0644',
  }

  file { $daemon:
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('roles_profiles/oci_registry/com.mozilla.oci-registry.plist.epp', {
      user        => $user,
      bin_path    => $bin_path,
      config_path => $config_path,
      log_path    => $log_path,
    }),
    require => [Exec['download_registry_binary'], File[$config_path], File[$log_path]],
    notify  => Exec['load_oci_registry_daemon'],
  }

  exec { 'load_oci_registry_daemon':
    command     => "/bin/bash -c 'launchctl bootout system ${daemon} 2>/dev/null || true; launchctl bootstrap system ${daemon}'",
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    require     => File[$daemon],
  }

  # Verify the registry process itself (direct, bypassing any proxy).
  exec { 'verify_oci_registry':
    command   => "/usr/bin/curl -fsSL http://localhost:${local_port}/v2/ || (echo 'Registry not reachable' && exit 1)",
    path      => ['/usr/bin', '/bin'],
    tries     => 5,
    try_sleep => 3,
    logoutput => on_failure,
    require   => Exec['load_oci_registry_daemon'],
  }

  # --- Push-auth reverse proxy (nginx): anonymous pull, authenticated push --
  $nginx_conf   = "${config_dir}/nginx.conf"
  $htpasswd     = "${config_dir}/htpasswd"
  $nginx_daemon = '/Library/LaunchDaemons/com.mozilla.oci-registry-nginx.plist'
  $nginx_bin    = '/opt/homebrew/bin/nginx'

  if $push_auth {
    # `brew install` writes into the prefix, so ${user} must own it. Ownership
    # can drift (seen on m4-194: /opt/homebrew/bin became non-admin-writable and
    # `brew install nginx` failed). Restore it before installing; the `unless`
    # keeps this a no-op once the prefix is correctly owned.
    exec { 'ensure_homebrew_admin_owned':
      command => "/usr/sbin/chown -R ${user} /opt/homebrew",
      unless  => "/bin/bash -c '/bin/test $(/usr/bin/stat -f %Su /opt/homebrew/bin) = ${user}'",
      path    => ['/usr/sbin', '/usr/bin', '/bin'],
      timeout => 600,
    }

    exec { 'install_nginx':
      command => "/usr/bin/su - ${user} -c '/opt/homebrew/bin/brew install nginx || true'",
      unless  => "/bin/test -x ${nginx_bin}",
      path    => ['/opt/homebrew/bin', '/usr/bin', '/bin'],
      timeout => 600,
      require => Exec['ensure_homebrew_admin_owned'],
    }

    file { $htpasswd:
      ensure    => file,
      owner     => 'root',
      group     => 'wheel',
      mode      => '0644',
      content   => "${push_htpasswd}\n",
      show_diff => false,
      require   => File[$config_dir],
      notify    => Exec['load_oci_registry_nginx'],
    }

    file { $nginx_conf:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      content => epp('roles_profiles/oci_registry/nginx.conf.epp', {
        registry_port => $registry_port,
        internal_port => $internal_port,
        htpasswd_path => $htpasswd,
      }),
      require => File[$config_dir],
      notify  => Exec['load_oci_registry_nginx'],
    }

    file { $nginx_daemon:
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      content => epp('roles_profiles/oci_registry/com.mozilla.oci-registry-nginx.plist.epp', {
        nginx_bin => $nginx_bin,
        conf_path => $nginx_conf,
      }),
      require => [Exec['install_nginx'], File[$nginx_conf], File[$htpasswd], Exec['verify_oci_registry']],
      notify  => Exec['load_oci_registry_nginx'],
    }

    exec { 'load_oci_registry_nginx':
      command     => "/bin/bash -c 'launchctl bootout system ${nginx_daemon} 2>/dev/null || true; launchctl bootstrap system ${nginx_daemon}'",
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
      require     => File[$nginx_daemon],
    }

    # Self-test: anonymous GET works, unauthenticated write is refused (401).
    exec { 'verify_push_auth':
      command   => "/bin/bash -c 'set -e; /usr/bin/curl -fsS http://localhost:${registry_port}/v2/ >/dev/null; code=\$(/usr/bin/curl -s -o /dev/null -w \"%{http_code}\" -X POST http://localhost:${registry_port}/v2/_authtest/blobs/uploads/); test \"\$code\" = 401'", # lint:ignore:140chars
      path      => ['/usr/bin', '/bin'],
      tries     => 5,
      try_sleep => 3,
      logoutput => on_failure,
      require   => Exec['load_oci_registry_nginx'],
    }
  } else {
    # Proxy disabled: ensure any previously-installed front-end is removed.
    exec { 'bootout_oci_registry_nginx':
      command => "/bin/bash -c 'launchctl bootout system ${nginx_daemon} 2>/dev/null || true'",
      onlyif  => "/bin/test -f ${nginx_daemon}",
      path    => ['/bin', '/usr/bin'],
    }
    file { [$nginx_daemon, $nginx_conf, $htpasswd]:
      ensure  => absent,
      require => Exec['bootout_oci_registry_nginx'],
    }
  }

  # --- Daily maintenance: tag retention + native garbage collection --------
  file { '/usr/local/bin/registry-maintenance.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    content => epp('roles_profiles/oci_registry/registry-maintenance.sh.epp', {
      user           => $user,
      bin_path       => $bin_path,
      config_path    => $config_path,
      registry_port  => $local_port,
      keep_prod_shas => $keep_prod_shas,
      prune_pr_shas  => $prune_pr_shas,
    }),
    require => Exec['verify_oci_registry'],
  }

  file { '/Library/LaunchDaemons/com.mozilla.registry-maintenance.plist':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('roles_profiles/oci_registry/com.mozilla.registry-maintenance.plist.epp', {
      hour => $maint_hour,
    }),
    require => File['/usr/local/bin/registry-maintenance.sh'],
    notify  => Exec['load_registry_maintenance_daemon'],
  }

  exec { 'load_registry_maintenance_daemon':
    command     => '/bin/bash -c \'launchctl bootout system /Library/LaunchDaemons/com.mozilla.registry-maintenance.plist 2>/dev/null || true; launchctl bootstrap system /Library/LaunchDaemons/com.mozilla.registry-maintenance.plist\'', # lint:ignore:140chars
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    require     => File['/Library/LaunchDaemons/com.mozilla.registry-maintenance.plist'],
  }

  # --- Periodic health + disk monitoring -----------------------------------
  file { '/usr/local/bin/registry-healthcheck.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    content => epp('roles_profiles/oci_registry/registry-healthcheck.sh.epp', {
      registry_port  => $registry_port,
      registry_dir   => $registry_dir,
      disk_threshold => $disk_threshold,
      alert_email    => $alert_email,
      smtp_relay     => $smtp_relay,
    }),
    require => Exec['verify_oci_registry'],
  }

  file { '/Library/LaunchDaemons/com.mozilla.registry-healthcheck.plist':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('roles_profiles/oci_registry/com.mozilla.registry-healthcheck.plist.epp', {
      interval => $health_interval,
    }),
    require => File['/usr/local/bin/registry-healthcheck.sh'],
    notify  => Exec['load_registry_healthcheck_daemon'],
  }

  exec { 'load_registry_healthcheck_daemon':
    command     => '/bin/bash -c \'launchctl bootout system /Library/LaunchDaemons/com.mozilla.registry-healthcheck.plist 2>/dev/null || true; launchctl bootstrap system /Library/LaunchDaemons/com.mozilla.registry-healthcheck.plist\'', # lint:ignore:140chars
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
    require     => File['/Library/LaunchDaemons/com.mozilla.registry-healthcheck.plist'],
  }
}
