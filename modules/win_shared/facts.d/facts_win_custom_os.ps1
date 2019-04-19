# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Custom facts based off OS details that are not included in the default facts

# Windows release ID.
#  From time to time we need to have the different releases of the same OS version
$release_id = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')
$win_os_build = [System.Environment]::OSVersion.Version.build

# Administrator SID
$administrator_info = Get-WmiObject win32_useraccount -Filter "name = 'Administrator'"
$win_admin_sid = $administrator_info.sid

write-host "custom_win_release_id=$release_id"
write-host "custom_win_admin_sid=$win_admin_sid"
