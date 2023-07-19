# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This is specific for creation of facts for items isntalled
# by the Mozilla Build package

# these are needed becuase we are unable to run validation commands
# or do a direct version validation of application

$mozbld_file  = "$env:systemdrive\mozilla-build\VERSION"
$hg_file      = "$env:ProgramW6432\Mercurial\hg.exe"
$python3_file = "$env:systemdrive\mozilla-build\python3\python3.exe"
$zstandard    = "$env:systemdrive\mozilla-build\python3\lib\site-packages\zstandard"

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

# Python 3 Pip
if (Test-Path $python3_file) {
    $pip_version = (C:\mozilla-build\python3\python3.exe -m pip --version)
    $py3_pip_version = [regex]::Matches($pip_version, "(\d+\.\d+\.\d+)").value
} else {
    $py3_pip_version = 0.0.0
}

# Pyhton 3 zstandard
if (Test-Path $python3_file) {
    $zstandard_info = (C:\mozilla-build\python3\python3.exe -m pip show zstandard)
    $zstandard_version = [regex]::Matches($zstandard_info, "(\d+\.\d+\.\d+)").value
} else {
    $zstandard_version = 0.0.0
}

write-host "custom_win_py3_pip_version=$py3_pip_version"
write-host "custom_win_mozbld_vesion=$mozbld_ver"
write-host "custom_win_hg_version=$hg_ver"
write-host "custom_win_py3_pip_version=$py3_pip_version"
write-host "custom_win_py3_zstandard_version=$zstandard_version"
