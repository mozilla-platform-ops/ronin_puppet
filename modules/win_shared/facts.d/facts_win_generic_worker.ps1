# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

$gw_file     = "$env:systemdrive\generic-worker\generic-worker.exe"

# Generic-worker

$serviceName = 'Generic Worker'

If (Get-Service $serviceName -ErrorAction SilentlyContinue) {
	$gw_service = "present"
} Else {
	$gw_service = "missing"
}

write-host "custom_win_genericworker_service=$gw_service"

# The command will typically write out multiple strings including stdout.
# There is need to drop what is is writen to stdout and selct the version
# out of the remaining string.
if (Test-Path $gw_file) {
	$gw_version = [regex]::match((& $gw_file --version 2> null), '^generic-worker (\d+\.\d+\.\d+) \[ revision: ([^ ]*) \]$').Groups[1].Value
} else {
    $gw_version = 0.0
}
write-host "custom_win_genericworker_version=$gw_version"

# workerType is set during proviosning (This may only be for hardware)
if (test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet") {
    $gw_workertype = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").workerType
    write-host "custom_win_gw_workerType=$gw_workertype"
}
