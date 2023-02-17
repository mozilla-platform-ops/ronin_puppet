# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/

$git = Get-command "git.exe"
if ($git) {
	$git_ver = "{0}.{1}.{2}" -f $git.Version.Major,$git.Version.Minor,$git.Version.Build
}
else {
	$git_ver = 0.0.0
}

write-host "custom_win_git_version=$git_ver"
