# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::gecko_t_osx_1300_r8_latest {

    include ::roles_profiles::profiles::timezone
    include ::roles_profiles::profiles::ntp
    include ::roles_profiles::profiles::network
#    include ::roles_profiles::profiles::disable_services
    include ::roles_profiles::profiles::vnc
#    include ::roles_profiles::profiles::suppress_dialog_boxes
#    include ::roles_profiles::profiles::power_management
#    include ::roles_profiles::profiles::screensaver
#    include ::roles_profiles::profiles::gui
    include ::roles_profiles::profiles::sudo
#    include ::roles_profiles::profiles::software_updates
#    include ::roles_profiles::profiles::hardware
    include ::roles_profiles::profiles::motd
    include ::roles_profiles::profiles::users
    include ::roles_profiles::profiles::relops_users
    include ::roles_profiles::profiles::cltbld_user
    include ::roles_profiles::profiles::packages_installed
    include ::roles_profiles::profiles::metrics
    include ::roles_profiles::profiles::worker
    # include ::roles_profiles::profiles::safariupdate
    # Manually enabled for this pool
    # include ::roles_profiles::profiles::safaridriver
    include macos_utils::disable_bluetooth_setup
    # include ::roles_profiles::profiles::pipconf
    # Disabling for this pool as it will probably be temporary
    include ::roles_profiles::profiles::macos_people_remover
    # This needs to re-worked if this pool is more permanent
    #include ::roles_profiles::profiles::macos_tcc_perms
}
