# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Creates useful facts based off of system environment variables

$systemdrive     = $env:systemdrive
$system32        = "$env:systemdrive\\windows\\system32"
$programdata     = $env:programdata.replace("\","\\")
$programfiles    = $env:ProgramW6432.replace("\","\\")
$programfilesx86 = "$systemdrive\\Program Files (x86)"

# Environment variables
write-host "systemdrive=$env:systemdrive"
write-host "system32=$system32"
write-host "programdata=$programdata"
write-host "programfiles=$programfiles"
write-host "programfilesx86=$programfilesx86"


# Facts built off of environment variables
write-host "roninprogramdata=$programdata\\PuppetLabs\\ronin"
write-host "roninsemaphoredir=$programdata\\PuppetLabs\\ronin\\semaphore"
write-host "tempdir=$env:systemdrive\\Windows\\Temp"

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520855
