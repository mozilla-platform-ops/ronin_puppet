# @summary reports whether the worker binaries hold an effective Screen Recording grant
#
# Detection only -- this class never changes TCC state. Obtaining the grant needs an
# administrator-authenticated approval in System Settings, which belongs in the
# provisioning path (relops-bootstrap), not here: puppet runs in the worker-start
# path with no admin credentials.
#
# Why detect at all: without the grant, every getDisplayMedia() call on the host
# fails with SCStreamErrorUserDeclined (-3801) and the only symptom is an
# intermittent orange on a random-looking subset of the pool. Bug 2073303 ran to
# 499 failures over 30 days (bug 1937556, sheriff-escalated) before it was traced
# to the hosts rather than to Gecko, because 42 of 174 hosts were silently
# incapable of screen capture and nothing on the host said so.
#
# An erase-and-reinstall re-enables SIP and wipes TCC, so a reprovisioned host comes
# back without the grant. That makes this a recurring condition, not a one-off, and
# is the reason it is worth a standing check rather than a one-time audit.
#
# The exec can never fail the run. worker-runner.sh calls run-puppet.sh
# synchronously before starting the worker and retries the whole apply every 60s
# while any "^Error:" is present, so a failing resource here would not degrade to
# "no screen capture", it would degrade to "this host never takes another task"
# (macmini-m4-84 sat dead from 2026-04-15 to 2026-08-11 that way, see #1323).
# The script's non-zero exit is the signal we want to record, not an error, so the
# exec swallows it and the JSON status file carries the state instead.
#
# @param enabled       Set false to remove the check from a role entirely.
# @param status_file   Where the JSON status is written, for telegraf/Hangar ingest.
class macos_screencapture_check (
  Boolean $enabled     = true,
  String  $status_file = '/var/tmp/screencapture-grant-status.json',
) {
  if $enabled and $facts['os']['name'] == 'Darwin' {
    case $facts['os']['release']['major'] {
      # Darwin 23/24/25/27 == macOS 14/15/26/27 (Darwin jumped to 27 with macOS 27). Earlier releases predate both the
      # SIP-on CI hardware and the Developer-ID-signed worker binaries.
      '23', '24', '25', '27': {
        $check_script = '/usr/local/bin/check-screencapture-grant.sh'

        file { $check_script:
          ensure  => file,
          content => file('macos_screencapture_check/check-screencapture-grant.sh'),
          mode    => '0755',
          owner   => 'root',
          group   => 'wheel',
        }

        # No TCC database and no worker binaries under test-kitchen, so the check
        # has nothing to report there; the file resource above is still asserted
        # so the suite can verify deployment.
        if $facts['running_in_test_kitchen'] != 'true' {
          # Runs on every apply and rewrites the status file, so the timestamp in
          # it doubles as a freshness signal: a stale checked_at means puppet
          # itself stopped running, which is worth knowing too.
          exec { 'record screen recording grant status':
            command     => "/bin/bash -c '${check_script} || true'",
            environment => ["SCREENCAPTURE_STATUS_FILE=${status_file}"],
            require     => File[$check_script],
            logoutput   => false,
          }
        }
      }
      default: {
        # Nothing to do on releases without SIP-on CI hardware.
      }
    }
  }
}
