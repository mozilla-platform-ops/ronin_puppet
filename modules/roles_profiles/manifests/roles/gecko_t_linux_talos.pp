# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::gecko_t_linux_talos {

    include ::roles_profiles::profiles::timezone
    include ::roles_profiles::profiles::relops_users
    # TODO: move more common stuff into gecko_linux_base
    include ::roles_profiles::profiles::gecko_linux_base
    include ::roles_profiles::profiles::ntp
    include ::roles_profiles::profiles::motd
    include ::roles_profiles::profiles::users
    include ::roles_profiles::profiles::sudo
    include ::roles_profiles::profiles::cltbld_user
    # linux desktop packages
    include ::roles_profiles::profiles::gui
    # nrpe and checks
    # TODO: required or are we migrating to influx?
    include ::fw::roles::linux_taskcluster_worker
    # google chrome
    # TODO: configure version and source
    include ::roles_profiles::profiles::google_chrome

    # TODO: from build-puppet
    # xwindows setup
    # intel drivers
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
        # generic_worker_sha256     => '6e5c1543fb3c333ca783d0a5c4e557b2b5438aada4bc23dc02402682ae4e245e',
        taskcluster_proxy_version => 'v5.1.0',
        # taskcluster_proxy_sha256  => '3faf524b9c6b9611339510797bf1013d4274e9f03e7c4bd47e9ab5ec8813d3ae',
        quarantine_worker_version => 'v1.0.0',
        # quarantine_worker_sha256  => '60bb15fa912589fd8d94dbbff2e27c2718eadaf2533fc4bbefb887f469e22627',
        user                      => 'cltbld',
        user_homedir              => '/home/cltbld',
    }

    ## copied from osx role
    # include ::roles_profiles::profiles::network
    # include ::roles_profiles::profiles::disable_services
    # include ::roles_profiles::profiles::ntp
    # include ::roles_profiles::profiles::vnc
    # include ::roles_profiles::profiles::suppress_dialog_boxes
    # include ::roles_profiles::profiles::power_management
    # include ::roles_profiles::profiles::screensaver
    # include ::roles_profiles::profiles::gui
    # include ::roles_profiles::profiles::software_updates
    # include ::roles_profiles::profiles::hardware
    # include ::roles_profiles::profiles::homebrew
    # include ::roles_profiles::profiles::gecko_t_osx_1014_generic_worker
    # include ::fw::roles::osx_taskcluster_worker

}
