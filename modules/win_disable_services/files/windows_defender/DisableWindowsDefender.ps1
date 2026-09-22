# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

function Invoke-CheckedCommand {
    param([string] $Path, [string[]] $Arguments)

    & $Path @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Path failed with exit code $LASTEXITCODE"
    }
}

function Remove-DefenderObjects {
    foreach ($view in 'Software\Classes', 'Software\Classes\Wow6432Node') {
        foreach ($object in @(
            'CLSID\{09A47860-11B0-4DA5-AFA5-26D86198A780}',
            'CLSID\{D8559EB9-20C0-410E-BEDA-7ED416AECC2A}',
            'CLSID\{13F6A0B6-57AF-4BA7-ACAA-614BC89CA9D8}',
            'CLSID\{195B4D07-3DE2-4744-BBF2-D90121AE785B}',
            'CLSID\{2781761E-28E0-4109-99FE-B9D127C57AFE}',
            'CLSID\{361290c0-cb1b-49ae-9f3e-ba1cbe5dab35}',
            'CLSID\{8a696d12-576b-422e-9712-01b9dd84b446}',
            'CLSID\{94F35585-C5D7-4D95-BA71-A745AE76E2E2}',
            'CLSID\{A2D75874-6750-4931-94C1-C99D3BC9D0C7}',
            'TypeLib\{8C389764-F036-48F2-9AE2-88C260DCF43B}',
            'CLSID\{A7C452EF-8E9F-42EB-9F2B-245613CA0DC9}',
            'CLSID\{DACA056E-216A-4FD1-84A6-C306A017ECEC}',
            'CLSID\{FDA74D11-C4A6-4577-9F73-D7CA8586E10D}'
        )) {
            $key = "HKEY_LOCAL_MACHINE\$view\$object"
            $path = "Registry::$key"
            if (Test-Path -LiteralPath $path) {
                ownRegistryKey -keyName $key
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
    }
}

function Set-DefenderRegistryValues {
    param([string] $Key, [hashtable] $Values)

    ownRegistryKey -keyName $Key
    $path = "Registry::$Key"
    if (!(Test-Path -LiteralPath $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    foreach ($value in $Values.GetEnumerator()) {
        New-ItemProperty -LiteralPath $path -Name $value.Key -PropertyType DWord -Value $value.Value -Force | Out-Null
    }
}

function Disable-DefenderFeaturesAndServices {
    $features = [ordered]@{
        '' = @{ DisableAntiSpyware = 1; DisableRoutinelyTakingAction = 1; ProductStatus = 0 }
        'Real-Time Protection' = @{ DisableAntiSpywareRealtimeProtection = 1; DisableRealtimeMonitoring = 1 }
        'Scan' = @{ AutomaticallyCleanAfterScan = 0; ScheduleDay = 8 }
        'UX Configuration' = @{ AllowNonAdminFunctionality = 0; DisablePrivacyMode = 1 }
    }
    foreach ($view in 'Software', 'Software\Wow6432Node') {
        foreach ($feature in $features.GetEnumerator()) {
            $key = "HKEY_LOCAL_MACHINE\$view\Microsoft\Windows Defender"
            if ($feature.Key) { $key += "\$($feature.Key)" }
            Set-DefenderRegistryValues $key $feature.Value
        }
    }
    foreach ($service in 'WinDefend', 'WdBoot', 'WdFilter', 'WdNisDrv', 'WdNisSvc') {
        foreach ($controlSet in 'ControlSet001', 'ControlSet002', 'CurrentControlSet') {
            Set-DefenderRegistryValues "HKEY_LOCAL_MACHINE\System\$controlSet\Services\$service" @{ Start = 4 }
        }
    }
}

function Disable-WindowsDefender {
    $ErrorActionPreference = 'Stop'

    if (Get-Process -Name MsMpEng -ErrorAction SilentlyContinue) {
        Write-Output 'Windows Defender is running.'
        foreach ($name in 'WdBoot.sys', 'WdFilter.sys', 'WdNisDrv.sys') {
            $path = "$env:SystemRoot\System32\drivers\$name"
            if (Test-Path -LiteralPath $path) {
                Invoke-CheckedCommand "$env:SystemRoot\System32\takeown.exe" @('/f', $path, '/a')
                Invoke-CheckedCommand "$env:SystemRoot\System32\icacls.exe" @($path, '/grant', '*S-1-5-32-544:F')
                Rename-Item -LiteralPath $path -NewName "$name.bak"
            }
        }
        Remove-DefenderObjects
        Write-Output 'Restart required.'
    }
    else {
        Write-Output 'Windows Defender is not running.'
        Disable-DefenderFeaturesAndServices

        foreach ($path in @(
            "$env:ProgramFiles\Windows Defender",
            "${env:ProgramFiles(x86)}\Windows Defender",
            "$env:ProgramData\Microsoft\Windows Defender"
        )) {
            if (Test-Path -LiteralPath $path) {
                Rename-Item -LiteralPath $path -NewName 'Windows Defender.bak'
            }
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    . "$PSScriptRoot\OwnRegistryKeys.ps1"
    requestPrivileges
    Disable-WindowsDefender
}
