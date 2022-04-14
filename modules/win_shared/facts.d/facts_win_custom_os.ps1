# Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Custom facts based off OS details that are not included in the default facts

# Windows release ID.
# From time to time we need to have the different releases of the same OS version
$release_key = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')
$release_id = $release_key.ReleaseId
$win_os_build = [System.Environment]::OSVersion.Version.build

# OS caption
# Used to determine which KMS license for cloud workers
$caption = ((Get-WmiObject Win32_OperatingSystem).caption)
$caption = $caption.ToLower()
$os_caption = $caption -replace ' ', '_'
# Windows activation status
$status = (Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%'" | where PartialProductKey).licensestatus

If ($status -eq '1') {
$kms_status = "activated"
} else {
$kms_status = "needs_activation"
}

# Administrator SID
$administrator_info = Get-WmiObject win32_useraccount -Filter "name = 'Administrator'"
$win_admin_sid = $administrator_info.sid

# Network profile
# https://bugzilla.mozilla.org/show_bug.cgi?id=1563287
$NetCategory =  Get-NetConnectionProfile | select NetworkCategory

if ($NetCategory -like '*private*') {
	$NetworkCategory = "private"
} else {
	$NetworkCategory = "other"
}

# Firewall status

$firewall_status = (netsh advfirewall show domain state)

if ($firewall_status -like "*off*") {
	$firewall_status = "off"
} else {
	$firewall_status = "running"
}

# Base image ID
#$role = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").role
$role = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").role

# Get worker pool ID
$worker_pool_id = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").worker_pool_id

if ($worker_pool_id -like "*gpu*") {
    $gpu = $true
} else {
    $gpu = $false
}

write-host "custom_win_release_id=$release_id"
write-host "custom_win_os_caption=$os_caption"
write-host "custom_win_kms_activated=$kms_status"
write-host "custom_win_admin_sid=$win_admin_sid"
Write-host "custom_win_net_category=$NetworkCategory"
Write-host "custom_win_firewall_status=$firewall_status"
Write-host "custom_win_role=$role"
write-host "custom_win_worker_pool_id=$worker_pool_id"
write-host "custom_win_gpu=$gpu"
