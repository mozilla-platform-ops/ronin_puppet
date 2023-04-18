# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::enable_long_paths {

  registry::value { 'LongPathsEnabled' :
    key  => 'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem',
    type => dword,
    data => '1',
  }
}
