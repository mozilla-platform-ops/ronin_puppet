# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::disable_notifications {

  # Using puppetlabs-registry
  registry::value { 'NoNewAppAlert':
    key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer',
    type => dword,
    data => '1',
  }
  registry_key { 'HKLM\System\CurrentControlSet\Control\Network\NewNetworkWindowOff':
    ensure => present,
  }

  # Bug 2002658: Disable the Action Center / notification center entirely.
  # Toast notifications from SecurityHealthSystray, RecoverabilityToastTask,
  # and other system components steal focus from test windows.
  registry::value { 'DisableNotificationCenter':
    key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer',
    type => dword,
    data => '1',
  }

  # Suppress toast notifications for all applications via Group Policy.
  registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications':
    ensure => present,
  }
  registry::value { 'NoToastApplicationNotification':
    key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications',
    type => dword,
    data => '1',
  }

  # Remove SecurityHealthSystray from startup. It triggers "device at risk"
  # toasts when WscDataProtection COM errors fire (Event 10016).
  registry::value { 'SecurityHealth':
    ensure => absent,
    key    => 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1562024
# https://bugzilla.mozilla.org/show_bug.cgi?id=1373551
# https://bugzilla.mozilla.org/show_bug.cgi?id=1397201#c58
# https://bugzilla.mozilla.org/show_bug.cgi?id=2002658
