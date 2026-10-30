# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Bug 2086189: stop OneDriveSetup.exe /thfirstsetup from starting at the first
# logon of each task user. It uses a full CPU core for the whole task.
class win_disable_services::disable_onedrive_setup {
  $script = "${facts['custom_win_roninprogramdata']}\\remove_default_user_onedrive_run.ps1"
  $powershell = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe"
  $run_script = "${powershell} -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ${script}"

  file { $script:
    ensure  => file,
    content => file('win_disable_services/onedrive/remove_default_user_run.ps1'),
  }

  exec { 'remove_default_user_onedrive_run':
    command   => $run_script,
    unless    => "${run_script} -Check",
    logoutput => true,
    require   => File[$script],
  }
}
