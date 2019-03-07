# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# these are needed becuase we are unable to run validation commands
# or do a direct version validation of application

$mozbld_file = "$env:systemdrive\mozilla-build\VERSION"
$hg_file     = "$env:ProgramW6432\Mercurial\hg.exe"

# Mozilla Build
# Needed in roles_profiles::profiles::mozilla_build
if (Test-Path $mozbld_file) {
	$mozbld_ver = (get-content $mozbld_file)
} else {
	$mozbld_ver = 0.0
}

# Mercurial
# Needed in roles_profiles::profiles::mozilla_build
if (Test-Path $hg_file) {
	$hg_object = Get-WMIObject Win32_Product | Where-Object {$_.Name -Like  'Mercurial*'}
	$hg_ver = $hg_object.version
} else {
    $hg_ver = 0.0
}
write-host "mozbld_ver=$mozbld_ver"
write-host "hg_ver=$hg_ver"
