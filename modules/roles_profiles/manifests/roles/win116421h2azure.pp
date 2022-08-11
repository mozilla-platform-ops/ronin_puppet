# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::win116421h2azure {
  # System
  include roles_profiles::profiles::disable_services
  include roles_profiles::profiles::suppress_dialog_boxes
  include roles_profiles::profiles::files_system_managment
  include roles_profiles::profiles::firewall
  include roles_profiles::profiles::network
  include roles_profiles::profiles::ntp
  include roles_profiles::profiles::power_management
  include roles_profiles::profiles::scheduled_tasks
  ## Is this trying to install each time it's run
  include roles_profiles::profiles::azure_vm_agent
  ## *_drivers depends on 7zip which isn't installed until common_tools
  include roles_profiles::profiles::virtual_drivers
  include roles_profiles::profiles::gpu_drivers

  # Adminstration
  include roles_profiles::profiles::logging
  include roles_profiles::profiles::common_tools

  # Worker
  include roles_profiles::profiles::git
  #include roles_profiles::profiles::mozilla_build
  ## Had to re-run mozilla_maintenance_service twice when mozilla_build wasn't a pre-req
  include roles_profiles::profiles::mozilla_maintenance_service
  include roles_profiles::profiles::windows_worker_runner
  #include roles_profiles::profiles::microsoft_tools
}
