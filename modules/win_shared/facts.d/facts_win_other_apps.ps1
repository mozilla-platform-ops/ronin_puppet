# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

$git = Test-Path "$ENV:ProgramFiles\Git\bin\git.exe"
if ($git) {
    $git_check = Get-Command "git.exe"
	$git_ver = "{0}.{1}.{2}" -f $git_check.Version.Major,$git_check.Version.Minor,$git_check.Version.Build
}
else {
	$git_ver = 0.0.0
}

write-host "custom_win_git_version=$git_ver"
