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

function Import-DefenderRegistry {
    param([string] $Name)

    $path = Join-Path $PSScriptRoot $Name
    Invoke-CheckedCommand "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', "$PSScriptRoot\OwnRegistryKeys.ps1", $path
    )
    Invoke-CheckedCommand "$env:SystemRoot\System32\reg.exe" @('import', $path)
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
        Import-DefenderRegistry 'DisableWindowsDefenderobjects.reg'
        Write-Output 'Restart required.'
    }
    else {
        Write-Output 'Windows Defender is not running.'
        Import-DefenderRegistry 'DisableWindowsDefenderfeatures.reg'
        Import-DefenderRegistry 'DisableWindowsDefenderservices.reg'

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
    Disable-WindowsDefender
}
