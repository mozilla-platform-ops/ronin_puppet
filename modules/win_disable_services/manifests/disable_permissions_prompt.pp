# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Class: win_disable_services::disable_permissions_prompt
# 
# This class disables the permissions prompt for the microphone in Windows.
#
class win_disable_services::disable_permissions_prompt {
  registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone':
    ensure => present,
    type   => string,
    data   => 'Allow',
  }
}
