# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

$service = 'sshd'

$result = (Get-Service $service -ErrorAction SilentlyContinue)
if ($result -eq $null) {
	$sshd_present = 'not_installed'
} else {
	$sshd_present = 'installed'
}

Write-host "custom_win_sshd=$sshd_present".
