# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::generic_worker {

    require roles_profiles::profiles::cltbld_user

    case $::operatingsystem {
        'Darwin': {

            $taskcluster_client_id    = lookup('taskcluster_client_id')
            $taskcluster_access_token = lookup('taskcluster_access_token')
            $livelog_secret           = lookup('livelog_secret')
            $quarantine_client_id     = lookup('quarantine_client_id')
            $quarantine_access_token  = lookup('quarantine_access_token')

            class { 'generic_worker':
                taskcluster_client_id     => $taskcluster_client_id,
                taskcluster_access_token  => $taskcluster_access_token,
                livelog_secret            => $livelog_secret,
                worker_group              => regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1'),
                quarantine_client_id      => $quarantine_client_id,
                quarantine_access_token   => $quarantine_access_token,
                generic_worker_version    => 'v13.0.3',
                taskcluster_proxy_version => 'v5.1.0',
                quarantine_worker_version => 'v1.0.0',
                user                      => 'cltbld',
                user_homedir              => '/Users/cltbld',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
