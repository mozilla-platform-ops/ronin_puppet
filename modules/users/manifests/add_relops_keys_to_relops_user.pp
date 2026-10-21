# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class users::add_relops_keys_to_relops_user {
  case $facts['os']['name'] {
    'Ubuntu': {
      # Make sure the users profile is required
      # That is where the user virtual resources are generated
      require roles_profiles::profiles::users
      # Lookup the relops group array and realize their user resource
      $relops = lookup('user_groups.relops', Array, undef, undef)
      realize(Users::Single_user[$relops])
      $all_users = lookup('all_users', Hash, undef, undef)

      # Manage authorized keys
      file { '/home/relops':
        ensure => directory,
        group  => 'relops',
        owner  => 'relops',
      }

      file { '/home/relops/.ssh':
        ensure => directory,
        group  => 'relops',
        mode   => '0700',
        owner  => 'relops',
      }

      file { '/home/relops/.ssh/authorized_keys':
        ensure  => file,
        group   => 'relops',
        mode    => '0600',
        owner   => 'relops',
        content => template("${module_name}/ssh_authorized_keys_relops.erb"),
      }

      # These virtual resources belong to users::all_users, not the profile
      # that realizes them. Order their contained homes and SSH keys directly
      # before replacing installer access with the shared relops key.
      Users::Single_user[$relops] -> File['/home/relops/.ssh/authorized_keys']
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
