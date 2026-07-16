# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Runs the local, insecure Docker-based OCI registry that serves Tart VM images
# to the tester fleet, and keeps it healthy over time.
#
# Resilience features added on top of the basic container:
#   * The container runs with --restart=always, and Colima itself is made
#     boot-persistent by roles_profiles::profiles::colima_docker, so the
#     registry returns on its own after a reboot.
#   * A daily maintenance LaunchDaemon prunes disposable tags and runs
#     `registry garbage-collect` so storage does not grow without bound
#     (registry:2 never reclaims deleted blobs on its own).
#   * A periodic health-check LaunchDaemon verifies /v2/ is reachable and that
#     the storage volume has headroom, writes a status file for dashboards to
#     scrape, and emails on trouble.
#
# Idempotency note: a *running* container of the expected name is left
# untouched (no needless bounce on every apply). Only a missing or stale
# (exited) container is (re)created. Storage lives in a host bind-mount, so
# recreating the container never loses image data.
class roles_profiles::profiles::oci_registry {
  $registry_port     = lookup('docker.registry_port',           Integer, 'first', 5000)
  $registry_network  = lookup('docker.registry_network',        String,  'first', 'bridge')
  $enable_delete     = lookup('oci_registry.enable_delete',     Boolean, 'first', true)
  $registry_dir      = lookup('oci_registry.registry_dir',      String,  'first', '/Users/admin/registry-data')
  $registry_name     = lookup('oci_registry.registry_name',     String,  'first', 'tart-registry')
  $user              = lookup('docker.user',                    String,  'first', 'admin')
  $keep_prod_shas    = lookup('oci_registry.keep_prod_shas',    Integer, 'first', 10)
  $prune_pr_shas     = lookup('oci_registry.prune_pr_shas',     Boolean, 'first', true)
  $maintenance_hour  = lookup('oci_registry.maintenance_hour',  Integer, 'first', 9)
  $disk_threshold    = lookup('oci_registry.disk_threshold_pct', Integer, 'first', 85)
  $health_interval   = lookup('oci_registry.health_interval',   Integer, 'first', 300)
  $alert_email       = lookup('oci_registry.alert_email',       String,  'first', 'releng-ci-alerts@mozilla.com')
  $smtp_relay        = lookup('oci_registry.smtp_relay',        String,  'first', 'smtp1.mail.mdc1.mozilla.com')

  $su          = "/usr/bin/su - ${user} -c"
  $docker      = '/opt/homebrew/bin/docker'
  $ps_name     = "${docker} ps --filter name=${registry_name} --format {{.Names}}"
  $ps_all_name = "${docker} ps -a --filter name=${registry_name} --format {{.Names}}"

  # Storage dir (host bind-mount). Managed as present only; ownership/mode left
  # alone so we never chown the large live data directory.
  file { $registry_dir:
    ensure => directory,
  }

  # Remove only a STALE (exists but not running) container before (re)creating.
  # A healthy running container is left as-is by the `unless` on the run exec.
  exec { 'remove_stale_registry_container':
    command   => "${su} 'PATH=/opt/homebrew/bin:\$PATH ${docker} rm -f ${registry_name}'",
    onlyif    => "${su} '${ps_all_name}' | grep -q ${registry_name}",
    unless    => "${su} '${ps_name}' | grep -q ${registry_name}",
    path      => ['/opt/homebrew/bin', '/usr/bin', '/bin'],
    logoutput => on_failure,
    require   => [Class['roles_profiles::profiles::colima_docker'], File[$registry_dir]],
  }

  $docker_run_cmd = "${su} 'PATH=/opt/homebrew/bin:\$PATH ${docker} run -d --network ${registry_network} -p ${registry_port}:${registry_port} --restart=always --name ${registry_name} -v ${registry_dir}:/var/lib/registry -e REGISTRY_HTTP_ADDR=0.0.0.0:${registry_port} -e REGISTRY_STORAGE_DELETE_ENABLED=${enable_delete} registry:2'" # lint:ignore:140chars

  exec { 'run_registry_container':
    command   => $docker_run_cmd,
    unless    => "${su} '${ps_name}' | grep -q ${registry_name}",
    path      => ['/opt/homebrew/bin', '/usr/bin', '/bin'],
    logoutput => on_failure,
    require   => Exec['remove_stale_registry_container'],
  }

  exec { 'verify_registry':
    command   => "/usr/bin/curl -fsSL http://localhost:${registry_port}/v2/ || (echo 'Registry not reachable' && exit 1)",
    path      => ['/usr/bin', '/bin'],
    tries     => 3,
    try_sleep => 5,
    logoutput => on_failure,
    require   => Exec['run_registry_container'],
  }

  # --- Daily maintenance: tag retention + garbage collection ----------------
  file { '/usr/local/bin/registry-maintenance.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    content => epp('roles_profiles/oci_registry/registry-maintenance.sh.epp', {
      user           => $user,
      registry_name  => $registry_name,
      registry_port  => $registry_port,
      keep_prod_shas => $keep_prod_shas,
      prune_pr_shas  => $prune_pr_shas,
    }),
    require => Exec['verify_registry'],
  }

  file { '/Library/LaunchDaemons/com.mozilla.registry-maintenance.plist':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    content => epp('roles_profiles/oci_registry/com.mozilla.registry-maintenance.plist.epp', {
      hour => $maintenance_hour,
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

  # --- Periodic health + disk monitoring ------------------------------------
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
    require => Exec['verify_registry'],
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
