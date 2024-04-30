# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::mozillavpn_b_1_osx {

    include ::roles_profiles::profiles::timezone
    include ::roles_profiles::profiles::ntp
    include ::roles_profiles::profiles::network
    #include ::roles_profiles::profiles::disable_services
    include ::roles_profiles::profiles::vnc
    #include ::roles_profiles::profiles::suppress_dialog_boxes
    #include ::roles_profiles::profiles::power_management
    #include ::roles_profiles::profiles::screensaver
    include ::roles_profiles::profiles::gui
    include ::roles_profiles::profiles::sudo
    #include ::roles_profiles::profiles::software_updates
    include ::roles_profiles::profiles::hardware
    include ::roles_profiles::profiles::motd
    include ::roles_profiles::profiles::users
    include ::roles_profiles::profiles::cltbld_user
    include ::roles_profiles::profiles::relops_users
    #include ::roles_profiles::profiles::homebrew
    include ::roles_profiles::profiles::worker
    #include ::fw::roles::osx_taskcluster_worker_loaner
    #include ::macos_utils::uninstall_homebrew
    include ::roles_profiles::profiles::macos_people_remover
}
