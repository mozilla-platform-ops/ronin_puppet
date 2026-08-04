# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Stages a "dynamic" xperf trace mechanism alongside the fixed
# win_hw_profiling::xperf_kernel_trace.
#
# Puppet ONLY puts the pieces in place: it drops the start/stop/register
# scripts and registers two SYSTEM scheduled tasks
# (xperf_dyn_trace_start / xperf_dyn_trace_stop). Puppet never runs the
# trace itself.
#
# At task run time an unprivileged task user chooses what to trace by
# writing an options file into their own profile:
#
#   C:\Users\<interactive-user>\xperf\xperf_dyn_options.json
#
# then triggers the pre-registered SYSTEM start/stop tasks (the register
# script grants BUILTIN\Users GR/GX so they can trigger, not modify). The
# start script reads the options file, validates it, and invokes ONLY
# xperf.exe with those options; if the file is missing or invalid it falls
# back to built-in defaults. See files/xperf_dyn_start.ps1 for the schema
# and the validation/containment rules.
class win_hw_profiling::xperf_dynamic_trace {

  $script_dir = $facts['custom_win_roninprogramdata']
  $ps         = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe"

  $dyn_start_ps1 = "${script_dir}\\xperf_dyn_start.ps1"
  $dyn_stop_ps1  = "${script_dir}\\xperf_dyn_stop.ps1"
  $dyn_setup_ps1 = "${script_dir}\\xperf_dyn_register_tasks.ps1"

  file { $dyn_start_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_dyn_start.ps1'),
  }

  file { $dyn_stop_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_dyn_stop.ps1'),
  }

  file { $dyn_setup_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_dyn_register_tasks.ps1'),
  }

  # Register/update the SYSTEM tasks ONLY when a script changes (first apply
  # counts as a change). Options changes happen in the run-time options file
  # and never require re-registration.
  exec { 'xperf_dyn_register_tasks':
    command     => "${ps} -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${dyn_setup_ps1}\" -StartScript \"${dyn_start_ps1}\" -StopScript \"${dyn_stop_ps1}\"",
    provider    => powershell,
    logoutput   => true,
    refreshonly => true,
    subscribe   => [
      File[$dyn_start_ps1],
      File[$dyn_stop_ps1],
      File[$dyn_setup_ps1],
    ],
  }
}
