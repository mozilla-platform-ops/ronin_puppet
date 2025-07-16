# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_talos_generic_worker {

    # TODO: make these args to this module and use in call in gecko_t_linux_talos?
    $worker_type  = 'gecko-t-linux-talos-1804'
    $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

    case $facts['os']['name'] {
        'Ubuntu': {
            require roles_profiles::profiles::cltbld_user

            class { 'roles_profiles::profiles::logging_papertrail':
                papertrail_host    => lookup( { 'name' => 'papertrail.host', 'default_value' => '' } ),
                papertrail_port    => lookup( { 'name' => 'papertrail.port', 'default_value' => -1 } ),
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
            # RELOPS-1318
            require linux_packages::pulseaudio

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

            $taskcluster_client_id    = lookup('generic_worker.gecko_t_linux_talos.taskcluster_client_id')
            $taskcluster_access_token = lookup('generic_worker.gecko_t_linux_talos.taskcluster_access_token')
            $livelog_secret           = lookup('generic_worker.gecko_t_linux_talos.livelog_secret')
            $quarantine_client_id     = lookup('generic_worker.gecko_t_linux_talos.quarantine_client_id')
            $quarantine_access_token  = lookup('generic_worker.gecko_t_linux_talos.quarantine_access_token')
            $bugzilla_api_key         = lookup('generic_worker.gecko_t_linux_talos.bugzilla_api_key')

            class { 'linux_generic_worker':
                taskcluster_client_id     => $taskcluster_client_id,
                taskcluster_access_token  => $taskcluster_access_token,
                livelog_secret            => $livelog_secret,
                worker_group              => $worker_group,
                worker_type               => $worker_type,
                quarantine_client_id      => $quarantine_client_id,
                quarantine_access_token   => $quarantine_access_token,
                bugzilla_api_key          => $bugzilla_api_key,
                generic_worker_version    => 'v61.0.0',
                generic_worker_sha256     => '9aed38c86c1c0417725a677318857266e51bd28e69b2e27586edd72e658af3f0',
                taskcluster_proxy_version => 'v61.0.0',
                taskcluster_proxy_sha256  => '639b3333cfefaf4d2e449c2962c20912e4449c3ffb9ab6d899c237d87e46712c',
                livelog_version           => 'v61.0.0',
                livelog_sha256            => '0513c85b3ad2f289961992ec166ee1e890ad033a1b485c29c69653049c369e23',
                start_worker_version      => 'v61.0.0',
                start_worker_sha256       => 'ddf74465e77e2a97a12c87a15dcd9599952127cb38b2e7040bc3177802b1151e',
                quarantine_worker_version => 'v1.0.0',
                quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
                user                      => 'cltbld',
                user_homedir              => '/home/cltbld',
            }

            require linux_generic_worker::check_gw

        }
        default: {
            fail("${facts['os']['name']} not supported")
        }
    }
}
