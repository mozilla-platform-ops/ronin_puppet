# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_generic_worker (
  String $worker_type,
  String $generic_worker_version,
  String $generic_worker_sha256,
  String $taskcluster_proxy_version,
  String $taskcluster_proxy_sha256,
  String $livelog_version,
  String $livelog_sha256,
  String $start_worker_version,
  String $start_worker_sha256,
  Optional[String] $lookup_key = undef,
  Boolean $include_py2 = false,
  Boolean $include_pulseaudio = false,
  Boolean $include_openbox = false,
  Boolean $include_cltbld_and_apt_cleaner = false,
  Boolean $include_netperf = false,
) {
  $worker_type_under = regsubst($worker_type, '-', '_', 'G')
  $secrets_key = $lookup_key ? {
    undef   => $worker_type_under,
    default => $lookup_key,
  }
  $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

  case $facts['os']['name'] {
    'Ubuntu': {
      require roles_profiles::profiles::cltbld_user

      class { 'roles_profiles::profiles::logging_papertrail':
        papertrail_host    => lookup({ 'name' => 'papertrail.host', 'default_value' => '' }),
        papertrail_port    => lookup({ 'name' => 'papertrail.port', 'default_value' => -1 }),
        systemd_units      => ['check_gw', 'run-puppet', 'ssh'],
        syslog_identifiers => ['generic-worker', 'run-start-worker', 'sudo'],
      }

      require linux_python
      # TODO: move these lines to linux-base?
      if $include_netperf {
        package { 'iperf3':
          ensure   => installed,
          provider => 'apt',
          before   => Class['linux_generic_worker'],
        }
      }
      if $include_py2 {
        require linux_packages::py2
        require linux_packages::psutil_py2
        require linux_packages::python2_zstandard
      }
      require linux_packages::py3
      package { 'ffmpeg':
        ensure => present,
        before => Class['linux_generic_worker'],
      }
      require linux_packages::imagemagick
      require linux_packages::psutil_py3
      require linux_packages::python3_zstandard
      require linux_packages::tooltool
      package { 'zstd':
        ensure => present,
        before => Class['linux_generic_worker'],
      }
      if $include_pulseaudio {
        package { 'pulseaudio-utils':
          ensure   => installed,
          provider => 'apt',
          before   => Class['linux_generic_worker'],
        }
      }
      if $include_openbox {
        package { 'openbox':
          ensure => latest,
          before => Class['linux_generic_worker'],
        }
      }

      # moved from base to avoid ordering issues with py2/3
      require linux_mercurial

      require linux_talos

      require linux_directory_cleaner
      if $include_cltbld_and_apt_cleaner {
        require linux_cltbld_and_apt_cleaner
      }

      class { 'puppet::atboot':
        telegraf_user     => lookup('telegraf.user'),
        telegraf_password => lookup('telegraf.password'),
        puppet_repo       => 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
        puppet_branch     => 'master',
        # Note the camelCase key names
        meta_data         => {
          workerType    => $worker_type,
          workerGroup   => $worker_group,
          provisionerId => 'releng-hardware',
          workerId      => $facts['networking']['hostname'],
        },
      }

      $taskcluster_client_id    = lookup("generic_worker.${secrets_key}.taskcluster_client_id")
      $taskcluster_access_token = lookup("generic_worker.${secrets_key}.taskcluster_access_token")
      $livelog_secret           = lookup("generic_worker.${secrets_key}.livelog_secret")
      $quarantine_client_id     = lookup("generic_worker.${secrets_key}.quarantine_client_id")
      $quarantine_access_token  = lookup("generic_worker.${secrets_key}.quarantine_access_token")
      $bugzilla_api_key         = lookup("generic_worker.${secrets_key}.bugzilla_api_key")

      class { 'linux_generic_worker':
        taskcluster_client_id     => $taskcluster_client_id,
        taskcluster_access_token  => $taskcluster_access_token,
        livelog_secret            => $livelog_secret,
        worker_group              => $worker_group,
        worker_type               => $worker_type,
        quarantine_client_id      => $quarantine_client_id,
        quarantine_access_token   => $quarantine_access_token,
        bugzilla_api_key          => $bugzilla_api_key,
        generic_worker_version    => $generic_worker_version,
        generic_worker_sha256     => $generic_worker_sha256,
        taskcluster_proxy_version => $taskcluster_proxy_version,
        taskcluster_proxy_sha256  => $taskcluster_proxy_sha256,
        livelog_version           => $livelog_version,
        livelog_sha256            => $livelog_sha256,
        start_worker_version      => $start_worker_version,
        start_worker_sha256       => $start_worker_sha256,
        quarantine_worker_version => 'v1.0.0',
        quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
        user                      => 'cltbld',
        user_homedir              => '/home/cltbld',
      }

      require linux_generic_worker::check_gw

      if $include_netperf {
        require linux_packages::caddy

        # cltbld needs to be able to run tc and caddy
        sudo::custom { 'allow cltbld to run tc':
          user    => 'cltbld',
          command => '/sbin/tc',
          runas   => 'ALL',
        }
        sudo::custom { 'allow cltbld to run caddy':
          user    => 'cltbld',
          command => '/usr/bin/caddy',
          runas   => 'ALL',
        }

        # Set MTU for loopback interface
        exec { 'set-lo-mtu':
          command => '/sbin/ip link set dev lo mtu 1500',
          path    => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
          unless  => '/sbin/ip link show lo | grep "mtu 1500"',
          user    => 'root',
        }
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
