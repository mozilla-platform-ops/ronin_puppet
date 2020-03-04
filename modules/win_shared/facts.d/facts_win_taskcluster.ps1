# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

$gw_file     = "$env:systemdrive\generic-worker\generic-worker.exe"
$scratch_file = "$ENV:WINDIR\temp\ver.txt"
$runner_file = "$env:systemdrive\worker-runner\start-worker.exe"
$taskcluster_proxy_file  = "$env:systemdrive\generic-worker\taskcluster-proxy.exe"

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
    cmd /c $gw_file --version > $scratch_file
    $gw_version = (select-string -Path $scratch_file -Pattern "\d+\.\d+\.\d+"| % { $_.Matches } | % { $_.Value })
    Remove-Item -Path $scratch_file -Force
} else {
    $gw_version = 0.0
}
write-host "custom_win_genericworker_version=$gw_version"

if (Test-Path $runner_file) {
	cmd /c $runner_file --version > $scratch_file
	$runner_version = (select-string -Path $scratch_file -Pattern "\d+\.\d+\.\d+"| % { $_.Matches } | % { $_.Value })
	Remove-Item -Path $scratch_file -Force
} else {
    $runner_version = 0.0
}
write-host "custom_win_runner_version=$runner_version"

if (Test-Path $runner_file) {
    cmd /c $taskcluster_proxy_file --version > $scratch_file
    $proxy_version = (select-string -Path $scratch_file -Pattern "\d+\.\d+\.\d+"| % { $_.Matches } | % { $_.Value })
    Remove-Item -Path $scratch_file -Force
} else {
    $proxy_version = 0.0
}
write-host "custom_win_taskcluster_proxy_version=$proxy_version"
# workerType is set during proviosning (This may only be for hardware)
if (test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet") {
    $gw_workertype = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").workerType
    write-host "custom_win_gw_workerType=$gw_workertype"
}
