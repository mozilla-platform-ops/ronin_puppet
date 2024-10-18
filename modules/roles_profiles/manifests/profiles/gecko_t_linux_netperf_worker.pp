# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_netperf_worker {
  $worker_type  = 'gecko-t-linux-netperf-1804'
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
      require linux_packages::py2
      require linux_packages::py3
      require linux_packages::ffmpeg
      require linux_packages::imagemagick
      require linux_packages::psutil_py2
      require linux_packages::psutil_py3
      require linux_packages::python2_zstandard
      require linux_packages::python3_zstandard
      require linux_packages::tooltool
      require linux_packages::zstd

      # moved from base to avoid ordering issues with py2/3
      require linux_mercurial

      require linux_talos

      require linux_directory_cleaner

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

      $taskcluster_client_id    = lookup('generic_worker.gecko_t_linux_netperf.taskcluster_client_id')
      $taskcluster_access_token = lookup('generic_worker.gecko_t_linux_netperf.taskcluster_access_token')
      $livelog_secret           = lookup('generic_worker.gecko_t_linux_netperf.livelog_secret')
      $quarantine_client_id     = lookup('generic_worker.gecko_t_linux_netperf.quarantine_client_id')
      $quarantine_access_token  = lookup('generic_worker.gecko_t_linux_netperf.quarantine_access_token')
      $bugzilla_api_key         = lookup('generic_worker.gecko_t_linux_netperf.bugzilla_api_key')

      class { 'linux_generic_worker':
        taskcluster_client_id     => $taskcluster_client_id,
        taskcluster_access_token  => $taskcluster_access_token,
        livelog_secret            => $livelog_secret,
        worker_group              => $worker_group,
        worker_type               => $worker_type,
        quarantine_client_id      => $quarantine_client_id,
        quarantine_access_token   => $quarantine_access_token,
        bugzilla_api_key          => $bugzilla_api_key,
        generic_worker_version    => 'v65.1.0',
        generic_worker_sha256     => 'ebd6773d0d61705e975c168bf58f9f0070c5abec46f34fc61590eaf5d3b1931f',
        taskcluster_proxy_version => 'v65.1.0',
        taskcluster_proxy_sha256  => '1c498f6f9390fa2bc069be747a24b4b17436cfd28df35e9adb38c48fab813985',
        livelog_version           => 'v65.1.0',
        livelog_sha256            => '543b66a900e49212b31fbe4fa4dd1a4e476597ae4f6ddb0ce48bba3437646dab',
        start_worker_version      => 'v65.1.0',
        start_worker_sha256       => '03f69ee42b51b493415fb25396922691992581af0d26df31bc87144f81a75285',
        quarantine_worker_version => 'v1.0.0',
        quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
        user                      => 'cltbld',
        user_homedir              => '/home/cltbld',
      }

      require linux_generic_worker::check_gw

      # install caddy
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
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
