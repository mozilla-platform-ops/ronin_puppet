function Get-WdFilterDriverPaths {
    param(
        [string] $DriverDirectory = (Join-Path $env:SystemRoot 'System32\drivers')
    )

    @(
        (Join-Path $DriverDirectory 'wd\WdFilter.sys')
        (Join-Path $DriverDirectory 'WdFilter.sys')
    )
}

function Rename-DefenderDriver {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    & "$env:SystemRoot\System32\takeown.exe" /f $Path /a | Out-Null
    & "$env:SystemRoot\System32\icacls.exe" $Path /grant 'Administrators:F' | Out-Null
    $backup = "$Path.bak"
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
    Rename-Item -LiteralPath $Path -NewName "$Name.sys.bak" -Force -ErrorAction Stop | Out-Null
    return $true
}
