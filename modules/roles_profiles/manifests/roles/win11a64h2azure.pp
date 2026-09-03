# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::win11a64h2azure (
  Boolean $tester,
) {
  include roles_profiles::profiles::azure_vm_file_system
  include roles_profiles::profiles::error_reporting

  # The cache drive can differ between Packer and worker-manager provisioning.
  # Keep this profile in both stages. It disables 8.3 names and last-access
  # updates, and it applies cache permissions after the cache drive is known.
  # See bugs 1863711 and 1305485.
  include roles_profiles::profiles::files_system_managment
  include roles_profiles::profiles::logging
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp

  # Tester images require GPU drivers and the Mozilla Maintenance Service.
  if $tester {
    include roles_profiles::profiles::gpu_drivers
    include roles_profiles::profiles::mozilla_maintenance_service
  }

  case $facts['custom_win_bootstrap_stage'] {
    # Keep the post-bootstrap catalog small to reduce the worker first-boot time.
    'complete': {
      # Apply the Mercurial cache state again after the cache drive is known.
      include roles_profiles::profiles::mozbuild_post_boostrap
    }
    default: {
      # Install Microsoft tools before disable_services disables Windows Update.
      include roles_profiles::profiles::microsoft_tools
      include roles_profiles::profiles::disable_services
      include roles_profiles::profiles::suppress_dialog_boxes
      include roles_profiles::profiles::firewall
      include roles_profiles::profiles::power_management
      include roles_profiles::profiles::scheduled_tasks
      include roles_profiles::profiles::azure_vm_agent
      include roles_profiles::profiles::mercurial
      include roles_profiles::profiles::git
      include roles_profiles::profiles::mozilla_build
      include roles_profiles::profiles::windows_worker_runner

      unless $tester {
        include roles_profiles::profiles::google_auth
      }
    }
  }
}
