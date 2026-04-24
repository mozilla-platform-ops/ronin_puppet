# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# TODO:
# - apache proxy setup?

class linux_generic_worker (
  String $taskcluster_client_id,
  String $taskcluster_access_token,
  String $livelog_secret,  # TODO: remove, not needed any longer
  String $worker_group,
  String $worker_type,
  String $quarantine_client_id,
  String $quarantine_access_token,
  String $bugzilla_api_key,
  String $user,
  String $user_homedir,
  Pattern[/^v\d+\.\d+\.\d+$/] $generic_worker_version,
  String $generic_worker_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
  String $taskcluster_proxy_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $livelog_version,
  String                      $livelog_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $start_worker_version,
  String                      $start_worker_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
  String $quarantine_worker_sha256,
  String $taskcluster_host = 'taskcluster',
) {
  # include httpd
  include shared

  # set hostname (not sure how this was working before)
  $hostname = $facts['networking']['hostname']

  class { 'packages::linux_generic_worker':
    generic_worker_version    => $generic_worker_version,
    generic_worker_sha256     => $generic_worker_sha256,
    taskcluster_proxy_version => $taskcluster_proxy_version,
    taskcluster_proxy_sha256  => $taskcluster_proxy_sha256,
    livelog_version           => $livelog_version,
    livelog_sha256            => $livelog_sha256,
    start_worker_version      => $start_worker_version,
    start_worker_sha256       => $start_worker_sha256,
    quarantine_worker_version => $quarantine_worker_version,
    quarantine_worker_sha256  => $quarantine_worker_sha256,
  }

  class { 'linux_generic_worker::control_bug':
    user_homedir     => $user_homedir,
    bugzilla_api_key => $bugzilla_api_key,
  }

  $livelog_certificate = "${user_homedir}/livelog.crt"
  $livelog_key         = "${user_homedir}/livelog.key"
  $task_dir            = "${user_homedir}/tasks"
  $caches_dir          = "${user_homedir}/caches"
  $downloads_dir       = "${user_homedir}/downloads"
  $ed25519_signing_key = "${user_homedir}/generic-worker.ed25519.signing.key"

  exec {
    'create ed25519 signing key':
      path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
      user    => $user,
      cwd     => $user_homedir,
      command => "generic-worker new-ed25519-keypair --file ${ed25519_signing_key}",
      unless  => "test -f ${ed25519_signing_key}",
      require => Class['packages::linux_generic_worker'];
  }

  # --force was added in 2020 (bug 1501936) to bypass a systemd hang on Ubuntu 18.04.
  # On 24.04 workers, --force bypasses systemd's orderly shutdown and appears to cause
  # silent hangs during driver teardown (mlx4_en/NVMe) on kernel 6.8.0+.
  # Using conditional to test without --force on 24.04 while leaving 18.04 unchanged.
  #
  # used in run-generic-worker file below
  $reboot_command = $facts['os']['release']['full'] ? {
    '24.04'  => '/usr/bin/sudo /sbin/reboot',
    default  => '/usr/bin/sudo /sbin/reboot --force',
  }

  file {
    default:
      owner => $user,
      # TODO: take this as an arg, don't assume
      group => $user;

    ["${user_homedir}/.config",
    "${user_homedir}/.config/autostart"]:
      ensure => directory;
    "${user_homedir}/.config/autostart/gnome-terminal.desktop":
      content => template('linux_generic_worker/gnome-terminal.desktop.erb');

    ["${user_homedir}/tasks", "${user_homedir}/downloads"]:
      ensure => directory;

    '/usr/local/bin/run-start-worker.sh':
      ensure  => file,
      content => template('linux_generic_worker/run-start-worker.sh.erb'),
      owner   => root,
      group   => root,
      mode    => '0755';

    '/usr/local/bin/run-start-worker-wrapper.sh':
      ensure => file,
      source => "puppet:///modules/${module_name}/run-start-worker-wrapper.sh",
      owner  => root,
      group  => root,
      mode   => '0755';

    '/etc/start-worker.yml':
      ensure  => file,
      content => template('linux_generic_worker/worker-runner-config.yml.erb'),
      owner   => root,
      group   => root,
      mode    => '0644';

    '/var/log/genericworker':
      ensure => directory,
      mode   => '0777';

    '/usr/local/bin/generic-worker-health-check':
      ensure => file,
      source => "puppet:///modules/${module_name}/generic-worker-health-check",
      owner  => root,
      group  => root,
      mode   => '0755';

    '/usr/local/bin/gwhc':
      ensure => link,
      target => '/usr/local/bin/generic-worker-health-check',
      owner  => root,
      group  => root;

    # workaround for https://bugs.launchpad.net/ubuntu/+source/gnome-settings-daemon/+bug/1764417
    # - happens occasionally. causes autostart scripts to not run.
    '/etc/systemd/system/graphical.target':
      ensure => file,
      source => "puppet:///modules/${module_name}/graphical.target",
      owner  => root,
      group  => root,
      mode   => '0644';
  }

  # TODO: cleanup
  # from build-puppet, seems not needed for modern talos/raptor

  #         host { $taskcluster_host:
  #             ip => '127.0.0.1'
  #         }

  #         httpd::config { 'proxy.conf':
  #             content => template('generic_worker/proxy-httpd.conf.erb'),
  #         }
}
