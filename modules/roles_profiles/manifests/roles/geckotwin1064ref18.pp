# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::geckotwin1064ref18 {

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
    # This role will use a different secrets file
    include roles_profiles::profiles::windows_datacenter_administrator

    # Worker
    include roles_profiles::profiles::mozilla_build
    include roles_profiles::profiles::mozilla_maintenance_service
    include roles_profiles::profiles::microsoft_tools
    include roles_profiles::profiles::windows_bitbar_generic_worker_16_2_0
}
