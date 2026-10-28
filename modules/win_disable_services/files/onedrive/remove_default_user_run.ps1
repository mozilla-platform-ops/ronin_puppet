# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

<#
Bug 2086189: the Default user profile starts "OneDriveSetup.exe /thfirstsetup"
at the first logon of each new user. Azure workers run each task as a new
user. On Windows 11 25H2 26200.9711 and later, the setup process uses a full
CPU core for the whole task. Remove the Run value from the Default user hive.

-Check exits 0 when the value is absent and 1 when it is present.
#>
param([switch] $Check)

$hive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
$mount = 'HKU\RoninDefaultUser'
$run = "$mount\Software\Microsoft\Windows\CurrentVersion\Run"
$names = @('OneDriveSetup', 'OneDrive')

if (-not (Test-Path -LiteralPath $hive)) {
    Write-Output "Default user hive missing: $hive"
    exit 2
}

& reg.exe load $mount $hive *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Output "reg load $hive failed (exit $LASTEXITCODE)"
    exit 2
}

$result = 0
try {
    foreach ($name in $names) {
        & reg.exe query $run /v $name *> $null
        if ($LASTEXITCODE -ne 0) { continue }
        if ($Check) { $result = 1; break }
        & reg.exe delete $run /v $name /f *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Output "reg delete $run /v $name failed (exit $LASTEXITCODE)"
            $result = 3
        } else {
            Write-Output "Removed $name from the Default user Run key"
        }
    }
} finally {
    & reg.exe unload $mount *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "reg unload $mount failed (exit $LASTEXITCODE)"
        $result = 4
    }
}
exit $result
