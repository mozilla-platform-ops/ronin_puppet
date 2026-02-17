# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

<<<<<<<< HEAD:modules/win_kms/manifests/set_key.pp
class win_kms::set_key (
    String $key
) {

    exec { 'set_kms_key':
        command  => epp('win_kms/set_kms_key.ps1'),
        provider => 'powershell',
    }

========
class roles_profiles::profiles::linux_directory_cleaner {
  class { 'linux_directory_cleaner':
    enabled    => true,
  }
>>>>>>>> origin/master:modules/roles_profiles/manifests/profiles/linux_directory_cleaner.pp
}
