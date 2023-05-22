# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_dec22patch::disable {
  registry_key { 'HKLM\SOFTWARE\Microsoft\.NETFramework\Windows Presentation Foundation\XPSAllowedTypes':
    ensure => present,
  }
  registry_value { 'HKLM\SOFTWARE\Microsoft\.NETFramework\Windows Presentation Foundation\XPSAllowedTypes\DisableDec2022Patch':
    ensure => present,
    type   => string,
    data   => '*',
  }
}
