# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

if (test-path "$env:ProgramW6432\Git\git-cmd.exe") {
	$git_version = ( cmd /c "$env:ProgramW6432\Git\cmd\git.exe" --version)
	$git_ver =  [regex]::Matches($git_version, "(\d+\.\d+\.\d+)").value
} else {
	$git_ver = 0.0.0
}

write-host "custom_win_git_version=$git_ver"
