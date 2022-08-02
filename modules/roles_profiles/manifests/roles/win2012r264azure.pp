# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::win2012r264azure {

    # Needs to be applied before other Win Update is disabled
    include roles_profiles::profiles::microsoft_tools

    # System
    include roles_profiles::profiles::disable_services
    include roles_profiles::profiles::suppress_dialog_boxes
    include roles_profiles::profiles::files_system_managment
    include roles_profiles::profiles::firewall
    include roles_profiles::profiles::network
    include roles_profiles::profiles::ntp
    include roles_profiles::profiles::power_management
    #include roles_profiles::profiles::scheduled_tasks
    include roles_profiles::profiles::azure_vm_agent

    # Adminstration
    include roles_profiles::profiles::logging
    include roles_profiles::profiles::common_tools

    # Worker
    include roles_profiles::profiles::git
    #include roles_profiles::profiles::mozilla_build
    include roles_profiles::profiles::mozilla_maintenance_service
    #include roles_profiles::profiles::windows_worker_runner
    #include roles_profiles::profiles::microsoft_tools
}
