# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Neutralise the tester VM image's build-time account on a running guest.
#
# See bug 2069268 (restricted) for the rationale. In short: the image build needs
# an account to provision through, that account is appropriate during a build and
# not in the shipped artifact, and it cannot simply be deleted -- macOS refuses,
# because it is the guest's only SecureToken holder:
#
#   User admin can not be deleted (it's either last admin user or last secure
#   token user neither of which can be deleted).
#
# So it is neutralised in place instead, in two steps that were measured to be
# independently necessary on a live guest:
#
#   1. drop it from the admin group. This closes group-wide sudo -- `sudo -l`
#      goes from full NOPASSWD to "not allowed to run sudo" -- and cascades away
#      com.apple.access_ssh, so it can no longer log in remotely either.
#
#   2. disable password authentication. Step 1 alone does NOT do this: a guest
#      with only step 1 applied still authenticated successfully against
#      `dscl . -authonly`, while one with both applied rejected it.
#
# Both execs are idempotent through group membership, which is also how the
# outcome is observable: pwpolicy -disableuser adds com.apple.access_disabled.
#
# *** DO NOT INCLUDE THIS FROM A TART HOST ROLE. ***
# The hosts have their own, unrelated account of the same name: it is the
# MDM-created local admin, it is tart.user, and it owns the running VMs.
# Neutralising it there would take the host out of service. This is only ever
# correct for the VM GUEST role, whose account is a build artifact.
#
# Recovery, if this ever needs undoing on a guest: puppet runs as root from a
# LaunchDaemon independently of this account, and cltbld retains SSH access.
class roles_profiles::profiles::disable_image_build_admin {
  case $facts['os']['name'] {
    'Darwin': {
      $build_user   = lookup('image_build_admin.user', String, 'first', 'admin')
      $build_marker = lookup('image_build_admin.build_marker', String, 'first', '/var/root/.image-build-in-progress')
      $paths        = ['/usr/bin', '/usr/sbin', '/bin', '/sbin']

      # Do nothing while an image build is in progress.
      #
      # The packer build provisions THROUGH this account -- every phase connects
      # as it, and packer's own graceful shutdown sudos as it. But the build also
      # runs run-puppet.sh in phase 1, which applies this whole role. Without this
      # guard the account is neutralised two phases early and the build wedges at
      # "Gracefully shutting down the VM" with "sudo: no password was provided".
      #
      # The build drops this marker before its first puppet run and removes it as
      # its last act, at which point it neutralises the account itself. So the
      # image ships in the same end state, just reached by the build rather than
      # by puppet mid-build.

      # `grep -w` on the group list, not a substring match: the account name also
      # appears inside unrelated group names such as _appserveradm.
      exec { 'demote_image_build_admin':
        command => "/usr/sbin/dseditgroup -o edit -d ${build_user} -t user admin",
        onlyif  => "/usr/bin/id -Gn ${build_user} | /usr/bin/grep -qw admin",
        unless  => "/bin/test -f ${build_marker}",
        path    => $paths,
      }

      # onlyif AND unless: without the existence check this would run pwpolicy
      # against a missing account on any guest built from an image that no longer
      # ships one, and fail the run.
      exec { 'disable_image_build_admin':
        command => "/usr/bin/pwpolicy -u ${build_user} -disableuser",
        onlyif  => "/usr/bin/id -u ${build_user}",
        unless  => [
          "/usr/bin/id -Gn ${build_user} | /usr/bin/grep -qw com.apple.access_disabled",
          "/bin/test -f ${build_marker}",
        ],
        path    => $paths,
        require => Exec['demote_image_build_admin'],
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
