# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

class roles_profiles::roles::win10642009hw {
  include roles_profiles::profiles::chocolatey
  ## Install before Widnows Updates is disabled.
  include roles_profiles::profiles::microsoft_tools
  include roles_profiles::profiles::ssh
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
  include roles_profiles::profiles::hardware
  #include roles_profiles::profiles::intel_drivers
  include roles_profiles::profiles::virtual_drivers
  include roles_profiles::profiles::windows_datacenter_administrator
  include roles_profiles::profiles::microsoft_kms

  # Adminstration
  include roles_profiles::profiles::logging
  include roles_profiles::profiles::common_tools
  include roles_profiles::profiles::nuc_management
  #include roles_profiles::profiles::vnc

  # Worker
  include roles_profiles::profiles::git
  include roles_profiles::profiles::mozilla_build_tester
  include roles_profiles::profiles::mozilla_maintenance_service
  include roles_profiles::profiles::windows_worker_runner
  include roles_profiles::profiles::windows_datacenter_administrator
}
