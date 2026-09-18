# @summary grants Screen Recording to the Taskcluster worker binaries on SIP-on hosts
#
# macos_tcc_perms writes the ScreenCapture grant straight into the system TCC
# database, which only works while SIP is off. On a SIP-on host that write
# silently fails and the user-database fallback it takes instead is inert,
# because kTCCServiceScreenCapture is a system-scoped service that TCC never
# reads from a user database. The observable result is that every
# getDisplayMedia() call on the host fails with SCStreamErrorUserDeclined
# (-3801) for the life of the host -- see bug 2073303, where this accounted for
# 42 of 174 hosts in gecko-t-osx-1500-m4 and presented as a ~20% intermittent
# purely because that is the share of the pool that is SIP-on.
#
# MDM cannot supply the grant. Apple accepts only
# AllowStandardUserToSetSystemService for ScreenCapture in a PPPC payload, which
# authorises a standard user to approve it rather than approving it; the row
# lands as auth_value 0 / auth_reason 6. There is also no consent dialog to
# automate -- tccd logs "Service kTCCServiceScreenCapture does not allow
# prompting; returning denied". The Screen Recording pane of System Settings is
# the only route, so this class drives it once per host.
#
# @param user The GUI-session user the worker runs tasks as, and therefore the
#   user whose session the approval is driven from.
class macos_screencapture_grant (
  Boolean $enabled = true,
  String  $user    = 'cltbld',
) {
  if $enabled and $facts['os']['name'] == 'Darwin' {
    # SIP-off hosts already get this from macos_tcc_perms' direct sqlite3 write,
    # and driving System Settings there would be pointless GUI churn on a host
    # that runs screen-pixel tests.
    if $facts['sip_enabled'] {
      case $facts['os']['release']['major'] {
        # Darwin 23/24/25 == macOS 14/15/26. Older releases in macos_tcc_perms'
        # list predate both SIP-on CI hardware and this pane's layout.
        '23', '24', '25': {
          $user_uid       = $facts['cltbld_uid']
          $applescript    = '/usr/local/bin/approve-screencapture.applescript'
          $check_script   = '/usr/local/bin/check-screencapture-grant.sh'
          $launchagent    = "/Users/${user}/Library/LaunchAgents/com.mozilla.screencapture.approve.plist"
          $semaphore_file = "/Users/${user}/Library/Preferences/semaphore/screencapture-grant-has-run"

          file { $applescript:
            content => file('macos_screencapture_grant/approve-screencapture.applescript'),
            mode    => '0755',
          }

          file { $check_script:
            content => file('macos_screencapture_grant/check-screencapture-grant.sh'),
            mode    => '0755',
          }

          # No GUI session exists under test-kitchen, and there is no TCC
          # database to read either, so the exec would fail rather than no-op.
          # The LaunchAgent is inside the guard for a second reason: it lands in
          # cltbld's home, which a kitchen runner has no guarantee of having
          # built out. macos_safaridriver scopes its own LaunchAgent the same way.
          if $facts['running_in_test_kitchen'] != 'true' {
            file { $launchagent:
              ensure  => file,
              owner   => $user,
              group   => 'staff',
              mode    => '0644',
              content => file('macos_screencapture_grant/com.mozilla.screencapture.approve.plist'),
            }

            # The stored code requirement comes from the PPPC override, so it is
            # anchored on identifier + Developer ID team rather than a cdhash.
            # That is why -- unlike the SIP-off path -- this survives a worker
            # version bump and needs no ordering against the binary install.
            # It does need the binaries present to be listed in the pane at all,
            # hence the collector.
            Packages::Macos_taskcluster_binary <| |> -> Exec['grant screen recording to worker binaries']

            # This exec MUST NOT fail, ever. worker-runner.sh calls
            # run-puppet.sh synchronously before it starts the worker, and
            # run-puppet.sh retries the whole apply every 60s while any
            # "^Error:" is present -- so a failing resource here does not
            # degrade to "no screen capture", it degrades to "this host never
            # takes another task". Reproduced on macmini-m4-111: the grant
            # could not be obtained at boot, the exec returned 1, and the host
            # sat in the retry loop with no worker until the branch was
            # reverted. This is the same wedge macos_tcc_perms' deferral was
            # added for in #1323 (macmini-m4-84, dead 2026-04-15 to 08-11).
            #
            # So the command always exits 0 and merely warns. That is safe
            # because `unless` reads the real TCC rows: a run that failed to
            # obtain the grant leaves those rows unchanged, so the next puppet
            # run simply tries again. Nothing is recorded as done that is not.
            #
            # The GUI precondition is checked first and bails out fast. The
            # approval needs cltbld's console session, which at boot may not
            # exist yet; without this check every such boot would burn the full
            # wait before starting the worker.
            #
            # The wait is on the semaphore rather than on the TCC rows because
            # the applescript writes the semaphore last, after closing System
            # Settings -- the grant lands several seconds earlier, so waiting on
            # the grant returns with a settings window still on screen, and
            # these hosts start screen-pixel tests as soon as puppet is done.
            $approve_cmd = [
              "if [ \"$(/usr/bin/stat -f%Su /dev/console)\" != \"${user}\" ]; then",
              "  echo \"WARNING: ${user} is not the console user; skipping Screen Recording approval this run.\" >&2;",
              "  echo \"WARNING: no semaphore written, so the next puppet run retries. Not failing --\" >&2;",
              "  echo \"WARNING: failing here would block worker startup (see worker-runner.sh).\" >&2;",
              '  exit 0;',
              'fi;',
              "rm -f ${semaphore_file};",
              "if /bin/launchctl print gui/${user_uid}/com.mozilla.screencapture.approve > /dev/null 2>&1; then",
              "  /bin/launchctl kickstart -k gui/${user_uid}/com.mozilla.screencapture.approve;",
              'else',
              "  /bin/launchctl bootstrap gui/${user_uid} ${launchagent};",
              'fi;',
              'count=0;',
              "while [ \$count -lt 90 ] && ! /bin/bash -c \"test -f ${semaphore_file} && grep -q 1 ${semaphore_file}\"; do sleep 2; count=\$((count+2)); done;",
              "if ! ${check_script}; then",
              "  echo \"WARNING: Screen Recording still not granted after \${count}s; will retry next puppet run.\" >&2;",
              'fi;',
              'exit 0',
            ].join(' ')

            exec { 'grant screen recording to worker binaries':
              command => "/bin/bash -c '${approve_cmd}'",
              unless  => $check_script,
              require => [File[$applescript], File[$check_script], File[$launchagent]],
              cwd     => "/Users/${user}",
              timeout => 180,
            }
          }
        }
        default: {
          # Nothing to do: no SIP-on CI hardware on these releases.
        }
      }
    }
  }
}
