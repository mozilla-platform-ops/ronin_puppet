# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Creates useful facts based off of system environment variables

$systemdrive     = $env:systemdrive
$system32        = "$systemdrive\\windows\\system32"
$programdata     = $env:programdata.replace("\","\\")
$programfiles    = $env:ProgramW6432.replace("\","\\")
$programfilesx86 = "$systemdrive\\Program Files (x86)"

# Environment variables
write-host "custom_win_systemdrive=$env:systemdrive"
write-host "custom_win_system32=$system32"
write-host "custom_win_programdata=$programdata"
write-host "custom_win_programfiles=$programfiles"
write-host "custom_win_programfilesx86=$programfilesx86"


# Facts built off of environment variables
write-host "custom_win_roninprogramdata=$programdata\\PuppetLabs\\ronin"
write-host "custom_win_roninsemaphoredir=$programdata\\PuppetLabs\\ronin\\semaphore"
write-host "custom_win_temp_dir=$systemdrive\\Windows\\Temp"

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520855
