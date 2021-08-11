<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

Do {

    $status = Get-Process rdpclip -ErrorAction SilentlyContinue
    If (!($status)) {
		Start-Sleep -Seconds 1
	}
    Else {
		$started = $true
	}
}
Until ( $started )

Stop-Process -Name rdpclip -force
