# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::win116424h2azure {
  case $facts['custom_win_bootstrap_stage'] {
    'complete': {
      ## Cache drive will change based on packer provision or worker manager provisioning
      include roles_profiles::profiles::error_reporting
      ## Keep it in here to disable 8dot3 and disablelastaccess and grant cache permissions for hg
      ## Bug list
      ## https://bugzilla.mozilla.org/show_bug.cgi?id=1863711
      ## https://bugzilla.mozilla.org/show_bug.cgi?id=1305485
      include roles_profiles::profiles::files_system_managment
      ## gpu drivers are needed for gpu images
      include roles_profiles::profiles::gpu_drivers
      ## Change log level from verbose to whatever hiera lookup is
      include roles_profiles::profiles::logging
      ## We need to configure the cache drive and hg-shared in this profile
      include roles_profiles::profiles::mozbuild_post_boostrap
      ## Set network to private
      include roles_profiles::profiles::network
      ## Let's assume the services keep spawning, so kill them again
      include roles_profiles::profiles::disable_services
      ## set UTC
      include roles_profiles::profiles::ntp
      ## errors if we don't have this, adding this
      include roles_profiles::profiles::mozilla_maintenance_service
      # Skip OOBE
      include roles_profiles::profiles::oobe
    }
    default: {
      # Install MS tools earlier
      include roles_profiles::profiles::microsoft_tools

      # System
      include roles_profiles::profiles::disable_services
      include roles_profiles::profiles::error_reporting
      include roles_profiles::profiles::suppress_dialog_boxes
      include roles_profiles::profiles::files_system_managment
      include roles_profiles::profiles::firewall
      include roles_profiles::profiles::network
      include roles_profiles::profiles::ntp
      include roles_profiles::profiles::power_management
      include roles_profiles::profiles::scheduled_tasks
      include roles_profiles::profiles::app_privacy
      include roles_profiles::profiles::azure_vm_agent
      include roles_profiles::profiles::virtual_drivers
      include roles_profiles::profiles::gpu_drivers

      # Skip OOBE
      include roles_profiles::profiles::oobe

      # Adminstration
      include roles_profiles::profiles::logging
      include roles_profiles::profiles::mercurial

      # Worker
      include roles_profiles::profiles::git
      include roles_profiles::profiles::mozilla_build
      include roles_profiles::profiles::mozilla_maintenance_service
      include roles_profiles::profiles::windows_worker_runner
    }
  }
}
