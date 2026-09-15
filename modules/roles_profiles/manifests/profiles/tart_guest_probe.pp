# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Unprivileged, key-only account the tart HOST uses to read a drain signal out
# of a tester GUEST.
#
# This replaces a shared-credential login previously used for the same purpose.
# Rationale is in bug 2069268 (restricted).
#
# The replacement is deliberately narrow:
#   * no privileged group membership, so group-wide sudo rules do not apply to it
#   * no password at all -- authentication is the injected public key only
#   * exactly two sudo commands, both pinned to literal argv
#
# The private half lives on the host (profiles::tart); only the public half is
# here, which is why it sits in plain role data.
class roles_profiles::profiles::tart_guest_probe {
  case $facts['os']['name'] {
    'Darwin': {
      $probe_user = lookup('tart_guest_probe.user', String, 'first', 'probe')
      $ssh_keys   = lookup('tart_guest_probe.ssh_keys', Array, 'first', [])
      $log_path   = lookup('tart_guest_probe.log_path', String, 'first', '/opt/worker/logs/stdout.log')

      # Fail loudly rather than create an account with no way to authenticate.
      # An empty list here would leave a keyless, passwordless user in the image
      # and silently dead probes -- the exact combination this profile exists to
      # avoid. Set tart_guest_probe.ssh_keys in the role data before applying.
      if empty($ssh_keys) {
        fail('tart_guest_probe.ssh_keys is empty -- refusing to create a probe account with no key')
      }

      users::single_user { $probe_user:
        shell    => '/bin/bash',
        ssh_keys => $ssh_keys,
        # No groups, no password: deliberately. See the header.
      }

      # A puppet-created macOS user cannot actually SSH in until it is a member of
      # the SSH service ACL group, even with a valid key. Without this the key
      # authenticates and the connection is then dropped by
      #   account required pam_sacl.so sacl_service=ssh
      # which reads as a mystery: ssh -vvv reports "Server accepts key" immediately
      # followed by "Connection closed", and nothing appears in the sshd log.
      #
      # Same dscl-append convention as profiles::cltbld_user, which is included by
      # the same role and is what creates this group in the first place.
      exec { "${probe_user}_group_com.apple.access_ssh":
        command => "/usr/bin/dscl . -append /Groups/com.apple.access_ssh GroupMembership ${probe_user}",
        unless  => "/usr/bin/groups ${probe_user} | /usr/bin/grep -q -w com.apple.access_ssh",
        require => Users::Single_user[$probe_user],
      }

      # The drain signal counts "REBOOT <date>" lines that worker-runner.sh
      # writes immediately before rebooting, AFTER the task resolved and
      # generic-worker exited. The log is 0700 cltbld, hence sudo -- but this is
      # the whole of the privilege, not a general escalation.
      #
      # sudo::custom writes a fragment into the managed /etc/sudoers concat, NOT
      # /etc/sudoers.d -- the sudo class removes that directory outright, so a
      # drop-in file here would be deleted on the next run.
      sudo::custom { "allow_${probe_user}_drain_signal":
        user    => $probe_user,
        command => "/usr/bin/grep -ac REBOOT ${log_path}",
        require => Users::Single_user[$probe_user],
      }

      # The health agent (relops-bootstrap tart_health_agent) reports which worker
      # a slot registered as, read out of the generic-worker config.
      #
      # That file also holds a credential, so the pattern is a fixed literal and
      # -m1 stops at the first hit: only the workerId line can reach stdout.
      #
      # The pattern deliberately contains NO glob metacharacters. sudoers matches
      # command arguments with fnmatch(3), where [...] is a single-character class
      # and * and ? are wildcards -- so a regex like mac-[0-9a-f]+ in this rule would
      # match the argument "mac-a+" and NOT the literal string the probe passes, and
      # sudo would silently deny it. Extracting the id from the line is left to the
      # caller, unprivileged.
      $worker_conf = lookup('tart_guest_probe.worker_conf', String, 'first', '/opt/worker/generic-worker.conf.yaml')
      sudo::custom { "allow_${probe_user}_worker_id":
        user    => $probe_user,
        command => "/usr/bin/grep -m1 workerId ${worker_conf}",
        require => Users::Single_user[$probe_user],
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
