# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

$gw_file     = "$env:systemdrive\generic-worker\generic-worker.exe"
$runner_file = "$env:systemdrive\worker-runner\start-worker.exe"
$taskcluster_proxy_file  = "$env:systemdrive\generic-worker\taskcluster-proxy.exe"

# Generic-worker
$gw_service = 'Generic Worker'

if (Get-Service $gw_service -ErrorAction SilentlyContinue) {
	$gw_service = "present"
} else {
	$gw_service = "missing"
}
write-host "custom_win_genericworker_service=$gw_service"

# The command will typically write out multiple strings including stdout.
# There is a need to drop what is written to stdout and select the version
# out of the remaining string.
if (Test-Path $gw_file) {
    $gw_version = & $gw_file --short-version
} else {
    $gw_version = "0.0"
}
write-host "custom_win_genericworker_version=$gw_version"

# worker-runner
$runner_service = 'worker-runner'
if (Get-Service $runner_service -ErrorAction SilentlyContinue) {
     $runner_service = "present"
} else {
    $runner_service = "missing"
}
write-host "custom_win_runner_service=$runner_service"

if (Test-Path $runner_file) {
	$runner_version = & $runner_file --short-version
} else {
    $runner_version = "0.0"
}
write-host "custom_win_runner_version=$runner_version"

# Taskcluster proxy
if (Test-Path $taskcluster_proxy_file) {
    $proxy_version = & $taskcluster_proxy_file --short-version
} else {
    $proxy_version = "0.0"
}
write-host "custom_win_taskcluster_proxy_version=$proxy_version"

# workerType is set during provisioning (This may only be for hardware).
if (test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet") {
    $gw_workertype = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").workerType
    write-host "custom_win_gw_workerType=$gw_workertype"
}

# Get worker pool ID
$worker_pool_id = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").worker_pool_id
write-host "custom_win_worker_pool_id=$worker_pool_id"

# Get deployment ID
$deployment_id = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").GITHASH
write-host "custom_win_deployment_id=$deployment_id"
