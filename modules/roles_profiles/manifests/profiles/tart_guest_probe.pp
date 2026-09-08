# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Unprivileged, key-only account the tart HOST uses to read a drain signal out
# of a tester GUEST.
#
# This replaces the guest `admin` account (password `admin`) that used to serve
# the same purpose. That account was created by the Setup Assistant automation
# in the macos-vms tester15 image build and never removed, and because the
# puppet-managed /etc/sudoers grants `%admin ALL=(ALL) NOPASSWD: ALL`, anything
# that could reach it had passwordless root inside a guest that is persistent
# and reused across trust levels. See Bug 2069268.
#
# The replacement is deliberately narrow:
#   * not in the admin group, so the %admin NOPASSWD rule does not apply to it
#   * no password at all -- authentication is the injected public key only
#   * exactly one sudo command, the log read the drain signal actually needs
#
# The private half lives on the host (profiles::tart writes it from vault); only
# the public half is here, which is why it sits in plain role data.
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
      # a slot registered as, which it reads out of the generic-worker config.
      #
      # That file also holds worker.access_token, so the pattern is a fixed literal
      # and -m1 stops at the first hit: only the workerId line can reach stdout, and
      # the access-token line does not contain "workerId".
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
