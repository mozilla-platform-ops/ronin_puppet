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

  # WER only reads the local dump settings from the LocalDumps subkey:
  # https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps
  # DumpCount 0 turns off dumps for all processes; the firefox.exe key turns
  # them back on for Firefox only.
  $local_dumps_key = "${error_report_key}\\LocalDumps"
  $firefox_dumps_key = "${local_dumps_key}\\firefox.exe"

  # Using puppetlabs-registry
  registry::value { 'LocalDumps DumpCount' :
    key   => $local_dumps_key,
    value => 'DumpCount',
    type  => dword,
    data  => '0',
  }
  registry::value { 'firefox.exe DumpFolder' :
    key   => $firefox_dumps_key,
    value => 'DumpFolder',
    type  => expand,
    data  => $dump_dir,
  }
  registry::value { 'firefox.exe DumpCount' :
    key   => $firefox_dumps_key,
    value => 'DumpCount',
    type  => dword,
    data  => '10',
  }
  registry::value { 'firefox.exe DumpType' :
    key   => $firefox_dumps_key,
    value => 'DumpType',
    type  => dword,
    data  => '1',
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
