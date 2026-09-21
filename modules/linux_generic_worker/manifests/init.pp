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
  Variant[String, Hash[String, String]] $generic_worker_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $taskcluster_proxy_version,
  Variant[String, Hash[String, String]] $taskcluster_proxy_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $livelog_version,
  Variant[String, Hash[String, String]] $livelog_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $start_worker_version,
  Variant[String, Hash[String, String]] $start_worker_sha256,
  Pattern[/^v\d+\.\d+\.\d+$/] $quarantine_worker_version,
  String $quarantine_worker_sha256,
  Enum['s3', 'github'] $taskcluster_binary_source = 's3',
  # The default retains the existing Linux insecure-worker deployment. A later
  # canary may opt into multiuser-static, which selects the upstream
  # generic-worker-multiuser asset but does not itself change startup identity
  # or task-user assignment.
  Enum['insecure', 'multiuser-static'] $generic_worker_engine = 'insecure',
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
    taskcluster_binary_source => $taskcluster_binary_source,
    generic_worker_engine     => $generic_worker_engine,
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
  $worker_state_dir = $generic_worker_engine ? {
    'multiuser-static' => '/var/lib/generic-worker',
    default            => $user_homedir,
  }
  $generic_worker_config_path = "${worker_state_dir}/generic-worker.config"
  $ed25519_signing_key        = "${worker_state_dir}/generic-worker.ed25519.signing.key"
  $worker_runner_config_mode = $generic_worker_engine ? {
    'multiuser-static' => '0600',
    default            => '0644',
  }
  $worker_process_user = $generic_worker_engine ? {
    'multiuser-static' => root,
    default            => $user,
  }
  $signing_key_require = $generic_worker_engine ? {
    'multiuser-static' => [Class['packages::linux_generic_worker'], File[$worker_state_dir]],
    default            => Class['packages::linux_generic_worker'],
  }

  if $generic_worker_engine == 'multiuser-static' {
    # This directory is the root-owned control plane for a later root Worker
    # Runner service. Task files, caches, and downloads deliberately stay under
    # the static task user's home directory.
    file { $worker_state_dir:
      ensure => directory,
      owner  => root,
      group  => root,
      mode   => '0700',
    }

    # Generic Worker reads this file relative to its working directory. Linux
    # uses the already-active GDM session for the selected account, so retaining
    # the account password here is unnecessary and would widen secret exposure.
    file { "${worker_state_dir}/next-task-user.json":
      ensure  => file,
      content => template('linux_generic_worker/next-task-user.json.erb'),
      owner   => root,
      group   => root,
      mode    => '0600',
      require => File[$worker_state_dir],
    }
  } else {
    # Keep the static worker identity for a possible later rollback, but remove
    # its task-user selection file so inactive static state cannot be mistaken
    # for an active control plane.
    file { '/var/lib/generic-worker/next-task-user.json':
      ensure => absent,
    }
  }

  exec {
    'create ed25519 signing key':
      path    => ['/bin', '/sbin', '/usr/local/bin', '/usr/bin'],
      user    => $worker_process_user,
      cwd     => $worker_state_dir,
      command => "generic-worker new-ed25519-keypair --file ${ed25519_signing_key}",
      unless  => "test -f ${ed25519_signing_key}",
      require => $signing_key_require;
  }

  if $generic_worker_engine == 'multiuser-static' {
    file { $ed25519_signing_key:
      ensure  => file,
      owner   => root,
      group   => root,
      mode    => '0600',
      require => Exec['create ed25519 signing key'],
    }
  }

  # According to bug 1501936, https://bugzilla.mozilla.org/show_bug.cgi?id=1501936,Linux machines stuck at reboot process.
  # Looking over the internet, I found this bug: https://lists.ubuntu.com/archives/foundations-bugs/2016-April/280724.html
  # They suspet systemd generate this behavior. I reproduced this by genereting a reboot cron job
  # and run it every 10 minutes.
  # After around 24 hours the worker stuck at reboot process. I tryed to update systemd to the last version,
  # but without success. To fix this, I plan to add --force option to reboot command,
  # to shutdown without contacting the system manager.
  # According reboot man page:
  # -f, --force - Force immediate halt, power-off, or reboot. When specified once,
  # this results in an immediate but clean shutdown by the system manager. When specified twice,
  # this results in an immediate shutdown without contacting the system manager.
  # See the description of --force in systemctl(1) for more details.
  #
  # used in run-generic-woker file below
  $reboot_command = '/usr/bin/sudo /sbin/reboot --force'

  file {
    default:
      owner => $user,
      # TODO: take this as an arg, don't assume
      group => $user;

    ["${user_homedir}/.config",
    "${user_homedir}/.config/autostart"]:
      ensure => directory;

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
      mode    => $worker_runner_config_mode;

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

  exec { 'reload linux generic worker systemd':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  if $generic_worker_engine == 'multiuser-static' {
    # The root service is the Worker Runner and credential control plane. The
    # Generic Worker multiuser binary waits for GDM to provide an interactive
    # session for $user before it launches a task under that account.
    file { "${user_homedir}/.config/autostart/gnome-terminal.desktop":
      ensure => absent,
    }

    file { '/usr/local/bin/run-generic-worker-root.sh':
      ensure  => file,
      content => template('linux_generic_worker/run-generic-worker-root.sh.erb'),
      owner   => root,
      group   => root,
      mode    => '0700',
      require => File[$worker_state_dir],
    }

    file { '/etc/systemd/system/generic-worker.service':
      ensure  => file,
      content => template('linux_generic_worker/generic-worker.service.erb'),
      owner   => root,
      group   => root,
      mode    => '0644',
      notify  => Exec['reload linux generic worker systemd'],
    }

    service { 'generic-worker.service':
      ensure   => running,
      enable   => true,
      provider => systemd,
      require  => [
        Exec['reload linux generic worker systemd'],
        File['/etc/start-worker.yml'],
        File['/usr/local/bin/run-generic-worker-root.sh'],
        File["${user_homedir}/.config/autostart/gnome-terminal.desktop"],
      ],
    }
  } else {
    # Explicitly undo static-mode startup state before restoring the legacy
    # per-user GNOME launcher. /var/lib/generic-worker is intentionally kept:
    # its signing key is the static worker identity and deleting it on a mode
    # change would be an unexpected destructive operation.
    service { 'generic-worker.service':
      ensure   => stopped,
      enable   => false,
      provider => systemd,
      before   => File['/etc/systemd/system/generic-worker.service'],
    }

    file { '/etc/systemd/system/generic-worker.service':
      ensure  => absent,
      notify  => Exec['reload linux generic worker systemd'],
      require => Service['generic-worker.service'],
    }

    file { '/usr/local/bin/run-generic-worker-root.sh':
      ensure => absent,
    }

    file { "${user_homedir}/.config/autostart/gnome-terminal.desktop":
      ensure  => file,
      content => template('linux_generic_worker/gnome-terminal.desktop.erb'),
      require => File["${user_homedir}/.config/autostart"],
    }
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
