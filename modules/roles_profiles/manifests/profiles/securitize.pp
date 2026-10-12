# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::securitize {
  case $facts['os']['name'] {
    'Ubuntu': {
      # relops user is created by kickstart script
      include users::remove_relops_pw
      include users::add_relops_keys_to_relops_user
      include users::remove_root_pw
      include users::remove_root_keys

      # Preserve relops SSH access before locking the bootstrap account or
      # removing the bootstrap root access. The relops file resources require
      # User[relops] for ownership, so order the password-lock command rather
      # than the whole class to avoid a dependency cycle.
      File['/home/relops/.ssh/authorized_keys']
        -> Exec['remove relops password']
        -> Class['users::remove_root_pw']
        -> Class['users::remove_root_keys']
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
