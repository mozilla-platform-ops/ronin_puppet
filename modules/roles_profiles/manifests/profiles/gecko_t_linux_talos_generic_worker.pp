# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gecko_t_linux_talos_generic_worker {

    case $::operatingsystem {
        'Ubuntu': {
            contain linux_packages::py2
            contain linux_packages::py3

            contain linux_packages::python2_zstandard
            contain linux_packages::python3_zstandard

            contain linux_packages::zstd

            # g-w
            $worker_type  = 'gecko-t-linux-talos'
            $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

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
                generic_worker_version    => 'v16.6.1',
                generic_worker_sha256     => '4f5c51e0e7bedf67baec3cfdccaa958c033cb109b334485882916f422071efd3',
                taskcluster_proxy_version => 'v5.1.0',
                taskcluster_proxy_sha256  => 'fcf000ca939b3ecbfc287405142f0f38ab4292b2f039ca9c6fc71fecfcfd065a',
                quarantine_worker_version => 'v1.0.0',
                quarantine_worker_sha256  => '42ea9e9df5dce6370750cf5141a400c07f781d3e28953a5f6d5066d4967a144c',
                user                      => 'cltbld',
                user_homedir              => '/home/cltbld',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
