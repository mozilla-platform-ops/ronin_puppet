# Kitchen supplies data from the checkout under test, not from the target VM.
$ErrorActionPreference = 'Stop'
if (-not $env:RONIN_TEST_DATA) { throw 'RONIN_TEST_DATA is required.' }
$Data = $env:RONIN_TEST_DATA | ConvertFrom-Json
$Role = $env:PUPPET_ROLE
$Worker = $Data.Role.'win-worker'
$Tester = $Worker.function -eq 'tester'
$Arm = $Role -like '*a64*'
$Server = $Role -like 'win202*'
$Win10 = $Role -eq 'win10642009azure'
$Win25 = $Role -eq 'win116425h2azure'
$Server25 = $Role -eq 'win20256424h2azure'
$TaskDrive = if ($Data.Role.windows_task_drive) { $Data.Role.windows_task_drive } else { 'D:' }
$Ronin = 'C:\ProgramData\PuppetLabs\ronin'
$DxSdk = 'C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)'

function Get-ExpectedValue {
    param([string[]]$Keys)
    foreach ($source in @($Worker.variant, $Worker, $Data.Windows)) {
        $value = $source
        foreach ($key in $Keys) { $value = $value.$key }
        if ($null -ne $value) { return $value }
    }
    throw "No expected value for $($Keys -join '.')"
}
