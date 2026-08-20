# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::error_reporting {
  # Bug 2002658: key path was Windows\Error\Reporting (three subkeys) instead
  # of "Windows Error Reporting" (single key with space). The wrong path meant
  # DontShowUI was never applied to the real WER key.
  $error_report_key = 'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting'

  $dump_drive = $facts['custom_win_systemdrive']
  $dump_dir = "${dump_drive}\\error-dumps"

  file { $dump_dir :
    ensure => directory,
  }

  # Using puppetlabs-registry
  registry::value { 'DumpFolder' :
    key  => $error_report_key,
    type => string,
    data => $dump_dir,
  }
  registry::value { 'LocalDumps' :
    key  => $error_report_key,
    type => dword,
    data => '1',
  }
  registry::value { 'DontShowUI' :
    key  => $error_report_key,
    type => dword,
    data => '1',
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1562024
# https://bugzilla.mozilla.org/show_bug.cgi?id=1694584
