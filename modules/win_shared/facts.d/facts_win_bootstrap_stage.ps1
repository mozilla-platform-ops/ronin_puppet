# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

if (test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet") {
	$bootstrap_stage = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
	write-host "custom_win_bootstrap_stage=$bootstrap_stage"
}
