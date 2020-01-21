# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::geckotwin1064refht {

  # Worker
    ## Generic worker
    include roles_profiles::profiles::windows_custom_config_generic_worker

    ## Mozilla Build
    include roles_profiles::profiles::mozilla_build

    ## Mozilla maintenance service
    include roles_profiles::profiles::mozilla_maintenance_service

    ## Microsoft tools
    include win_packages::vc_redist_x86
    include win_packages::vc_redist_x64
    include win_os_settings::powershell_profile

  # Administration
    ## Admin Password
    class { 'win_users::administrator::account':
        admin_password => lookup('win_adminpw'),
    }

    ## Logging
    include roles_profiles::profiles::logging

    ## Common tools
    include win_packages::process_debug
    include win_packages::jq
    include win_packages::gpg4win
    include win_packages::sevenzip
    include win_packages::sublimetxt

    # system
    ## disabled services
    include win_disable_services::disable_wsearch
    include win_disable_services::disable_puppet
    include win_disable_services::disable_windows_defender
    include win_disable_services::disable_windows_update
    include win_disable_services::disable_onedrive

    ## File System management
    include win_filesystem::disable8dot3
    include win_filesystem::disablelastaccess

    ## Ntp
    $ntpserver = lookup('windows.external.ntp')

    class { 'windowstime':
        servers  => { "${ntpserver}" => '0x08'},
        timezone => 'Greenwich Standard Time',
    }

    ## Power management
    class { 'windows::power_scheme':
        ensure => 'High performance',
    }

    ## Schedule Tasks
    include win_scheduled_tasks::maintain_system

}
