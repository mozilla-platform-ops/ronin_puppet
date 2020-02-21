# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_rotate_secrets {

# WARNING!!! The underlying define type will need to be adjusted to be used again.
# File comparison will be needed added for the target file.
# Leaving in place until Vault is in use on Windows hardware

    case $::operatingsystem {
        'Windows': {
            class { 'win_shared::gpg_files':
                file_name   => "${facts['custom_win_gw_workertype']}_vault.yaml.gpg",
                destination => "${facts['custom_win_systemdrive']}\\ronin\\data\\secrets\\vault.yaml",
            }
      #  This predicated on having a gpg key in C:\GPG\ named $workerType.gpg
      #  As well as the encrypted file in s3 at the location specified in hiera
      #  This is a temporary hack that should not be left in place in nodes
      #  This should be removed from the role after the file is updated
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
