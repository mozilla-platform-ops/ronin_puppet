param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('x86', 'x64')]
    [string] $Arch
)

$uninstallPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$displayNamePattern = "^Microsoft Visual C\+\+ 2015-2022 Redistributable \($Arch\)"
$displayVersionPattern = '^14\.\d+\.\d+(?:\.\d+)?$'

$match = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
    Where-Object {
        $_.DisplayName -match $displayNamePattern -and
        $_.DisplayVersion -match $displayVersionPattern
    } |
    Select-Object -First 1

if ($null -eq $match) {
    exit 1
}

exit 0
