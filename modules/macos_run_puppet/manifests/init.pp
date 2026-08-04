# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#
# @param enabled
#   Place run-puppet.sh and its shared shell functions.
# @param schedule_enabled
#   Also install a LaunchDaemon that runs run-puppet.sh on a timer. Defaults to
#   false: CI worker roles converge as part of the task lifecycle and must not have
#   a second, unrelated apply firing underneath a running job. Turn it on for
#   off-CI hosts that nothing else ever converges -- see
#   roles/gecko_t_osx_1500_m4_reprovision_runner, where the last apply before this
#   was 5 days stale because convergence was entirely manual.
# @param schedule_interval
#   Seconds between runs. Minimum 900 so a mistyped value can't hammer GitHub (each
#   run clones/fetches ronin_puppet).
#
class macos_run_puppet (
  Boolean       $enabled           = true,
  Boolean       $schedule_enabled  = false,
  Integer[900]  $schedule_interval = 3600,
) {
  if $enabled {
    # place shell functions file that has metadata genration code
    # - linux uses /etc/puppet/lib, use /opt/puppet_environments/lib/ instead on macOS
    file { '/opt/puppet_environments':
      ensure => directory,
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }
    file { '/opt/puppet_environments/lib':
      ensure  => directory,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0755',
      require => File['/opt/puppet_environments'],
    }

    file { '/opt/puppet_environments/lib/puppet_state_functions.sh':
      ensure => file,
      source => "puppet:///modules/${module_name}/puppet_state_functions.sh",
      owner  => 'root',
      group  => 'wheel',
      mode   => '0644',
    }

    file { '/usr/local/bin/run-puppet.sh':
      ensure => file,
      source => 'puppet:///modules/macos_run_puppet/run-puppet.sh',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    if $schedule_enabled {
      $sched_label      = 'com.mozilla.run_puppet'
      $sched_plist_path = "/Library/LaunchDaemons/${sched_label}.plist"
      $sched_log_dir    = '/var/log/puppet_runs'

      file { $sched_log_dir:
        ensure => directory,
        owner  => 'root',
        group  => 'wheel',
        mode   => '0750',
      }

      file { $sched_plist_path:
        ensure  => file,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0644',
        content => epp("${module_name}/${sched_label}.plist.epp", {
            label    => $sched_label,
            script   => '/usr/local/bin/run-puppet.sh',
            interval => $schedule_interval,
            log_out  => "${sched_log_dir}/run-puppet.out",
            log_err  => "${sched_log_dir}/run-puppet.err",
        }),
        require => [File['/usr/local/bin/run-puppet.sh'], File[$sched_log_dir]],
        notify  => Exec['macos_run_puppet_schedule_reload'],
      }

      # bootout then bootstrap so an edited plist is actually re-read; kickstart
      # alone keeps the old definition.
      exec { 'macos_run_puppet_schedule_reload':
        command     => "/bin/bash -c 'launchctl bootout system ${sched_plist_path} 2>/dev/null || true; launchctl bootstrap system ${sched_plist_path}'",
        path        => ['/bin', '/usr/bin'],
        refreshonly => true,
        require     => File[$sched_plist_path],
      }
    }
  }
}
