# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::geckotwin1064ht {

    # System
    include roles_profiles::profiles::disable_services
    include roles_profiles::profiles::files_system_managment
    include roles_profiles::profiles::firewall
    include roles_profiles::profiles::ntp
    include roles_profiles::profiles::power_management
    include roles_profiles::profiles::scheduled_tasks

    # Adminstration
    include roles_profiles::profiles::logging
    include roles_profiles::profiles::common_tools
    include roles_profiles::profiles::microsoft_network_services
    include roles_profiles::profiles::vnc
    # Openssh Fails when Puppet runs as a  schedule task
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1544141
    # include roles_profiles::profiles::ssh

    # Worker
    include roles_profiles::profiles::mozilla_build
    include roles_profiles::profiles::mozilla_maintenance_service
    include roles_profiles::profiles::windows_datacenter_generic_worker
    include roles_profiles::profiles::microsoft_tools
}
