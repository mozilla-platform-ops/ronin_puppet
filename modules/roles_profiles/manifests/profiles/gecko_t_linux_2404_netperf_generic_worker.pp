# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_2404_netperf_generic_worker {
  # TODO: make these args to this module and use in call in gecko_t_linux_talos?
  $worker_type  = 'gecko-t-linux-netperf-2404'
  $worker_type_under = regsubst($worker_type, '-', '_', 'G')
  $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

  case $facts['os']['name'] {
    'Ubuntu': {
      require roles_profiles::profiles::cltbld_user

      class { 'roles_profiles::profiles::logging_papertrail':
        papertrail_host    => lookup({ 'name' => 'papertrail.host', 'default_value' => '' }),
        papertrail_port    => lookup({ 'name' => 'papertrail.port', 'default_value' => -1 }),
        systemd_units      => ['run-puppet', 'ssh'],
        syslog_identifiers => ['generic-worker', 'run-start-worker', 'sudo'],
      }

      require linux_python
      # TODO: move these lines to linux-base?
      require linux_packages::py3
      require linux_packages::ffmpeg
      require linux_packages::imagemagick
      require linux_packages::psutil_py3
      require linux_packages::python3_zstandard
      require linux_packages::tooltool
      require linux_packages::zstd

      # moved from base to avoid ordering issues with py2/3
      require linux_mercurial

      require linux_talos

      require linux_directory_cleaner
      require linux_cltbld_and_apt_cleaner

      $puppet_repo                  = 'https://github.com/mozilla-platform-ops/ronin_puppet.git'
      $github                       = lookup('github', Hash, 'first', {})

      class { 'puppet::atboot':
        telegraf_user      => lookup('telegraf.user'),
        telegraf_password  => lookup('telegraf.password'),
        puppet_repo        => $puppet_repo,
        puppet_branch      => 'master',
        github_deploy_keys => dig($github, 'deploy_keys'),
        # Note the camelCase key names
        meta_data          => {
          workerType    => $worker_type,
          workerGroup   => $worker_group,
          provisionerId => 'releng-hardware',
          workerId      => $facts['networking']['hostname'],
        },
      }

      $taskcluster_client_id    = lookup("generic_worker.${worker_type_under}.taskcluster_client_id")
      $taskcluster_access_token = lookup("generic_worker.${worker_type_under}.taskcluster_access_token")
      $livelog_secret           = lookup("generic_worker.${worker_type_under}.livelog_secret")

      class { 'linux_generic_worker':
        taskcluster_client_id     => $taskcluster_client_id,
        taskcluster_access_token  => $taskcluster_access_token,
        livelog_secret            => $livelog_secret,
        worker_group              => $worker_group,
        worker_type               => $worker_type,
        taskcluster_binary_source => 'github',
        generic_worker_version    => 'v115.0.1',
        generic_worker_sha256     => '99400c60759475ee0a484e602f68b5e1ac9a295d1f2eef1b3e8e7dccfefdc31f',
        taskcluster_proxy_version => 'v115.0.1',
        taskcluster_proxy_sha256  => 'c1b7ff32e04825072482ff6b6a0f1fb766f98ec21da000054b5ab63fbcb53c85',
        livelog_version           => 'v115.0.1',
        livelog_sha256            => '3091a808cf225f34b40532b7c90e6cb3cf638268ca6c38cb7fcbe4de1c0e55b2',
        start_worker_version      => 'v115.0.1',
        start_worker_sha256       => '5cd2950d3b24088339399b91e494a81e0f2007a489e21d2721311c6b4a4cb01f',
        user                      => 'cltbld',
        user_homedir              => '/home/cltbld',
      }

      require linux_generic_worker::check_gw

      #
      # net-perf deviations from talos
      #
      require linux_packages::caddy
      require linux_packages::iperf
      require linux_packages::netperf_tc

      sudo::custom { 'allow cltbld to run netperf tc wrapper':
        user    => 'cltbld',
        command => '/usr/local/bin/netperf-tc',
      }

      # Set MTU for loopback interface
      exec { 'set-lo-mtu':
        command => '/sbin/ip link set dev lo mtu 1500',
        path    => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
        unless  => '/sbin/ip link show lo | grep "mtu 1500"',
        user    => 'root',
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
