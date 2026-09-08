# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Remove the tester VM image's build-time `admin` account from a running guest.
#
# Bug 2069268. The macos-vms tester15 build drives the Setup Assistant to create
# `admin` with the password `admin` and SSHes in as it for every provisioning
# phase. The account is never removed, so it ships in the image -- and because
# the puppet-managed /etc/sudoers grants `%admin ALL=(ALL) NOPASSWD: ALL`, any
# task that could reach it had passwordless root inside a guest that is
# persistent and reused across trust levels.
#
# macos-vms#48 removes it at build time. This profile removes it from guests that
# are ALREADY RUNNING, so the exposure can be closed without waiting on an image
# rebuild and a reroll of every slot. Once the new image is in service this
# becomes a no-op.
#
# *** DO NOT INCLUDE THIS FROM A TART HOST ROLE. ***
# The hosts have their own, unrelated `admin` account: it is the MDM-created
# local admin, it is tart.user, and it owns the running VMs. Removing it there
# would take the host out of service. This is only ever correct for the VM GUEST
# role (gecko_t_osx_1500_m_vms), whose admin is a build artifact.
#
# Ordering note: the role applies profiles::tart_guest_probe before this, so the
# replacement drain-signal account exists before the old one is taken away.
class roles_profiles::profiles::remove_image_build_admin {
  case $facts['os']['name'] {
    'Darwin': {
      $build_admin = lookup('image_build_admin.user', String, 'first', 'admin')
      $scan_dirs   = '/usr/local /opt /Library /etc'

      # Reassign what it owns BEFORE the account goes.
      #
      # /usr/local/bin/set_hostname.sh and /usr/local/bin/vault-inject.sh ship
      # owned by this account -- the packer file provisioner uploads them as
      # admin and `sudo mv` preserves that -- and both are executed by root
      # LaunchDaemons at boot. Verified on mac-63446b, where admin is uid 501.
      #
      # Deleting the account without this leaves them owned by an orphaned uid
      # 501, the first uid macOS hands out, so the next account created on the
      # guest would own two scripts root runs at boot. That would replace one
      # escalation path with another.
      exec { 'reassign_image_build_admin_files':
        command => "/usr/bin/find ${scan_dirs} -xdev -user ${build_admin} -exec /usr/sbin/chown root:wheel {} +",
        onlyif  => "/usr/bin/id -u ${build_admin} && /usr/bin/find ${scan_dirs} -xdev -user ${build_admin} -print -quit | /usr/bin/grep -q .",
        path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      }

      user { $build_admin:
        ensure  => absent,
        require => Exec['reassign_image_build_admin_files'],
      }

      # Explicit rather than managehome: the directoryservice provider's home
      # handling is unreliable, and leaving the home behind would keep the
      # account's authorized_keys and shell history on disk.
      file { "/Users/${build_admin}":
        ensure  => absent,
        force   => true,
        backup  => false,
        require => User[$build_admin],
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
