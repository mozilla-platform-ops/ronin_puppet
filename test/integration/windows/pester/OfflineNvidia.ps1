$ErrorActionPreference = 'Stop'
$driverName = 'ronin_puppet_offline_nvidia_grid_test'
$driverPath = "C:\Windows\Temp\$driverName.exe"
$manifestPath = "C:\Windows\Temp\$driverName.pp"
$puppetLog = "C:\Windows\Temp\$driverName.log"
Set-Content -Path $driverPath -Value 'preseeded installer' -NoNewline -Encoding ASCII
try {
    $env:FACTER_custom_win_gpu = 'no'
    $env:FACTER_custom_win_temp_dir = 'C:\Windows\Temp'
    $env:NO_COLOR = '1'
    $puppet = Join-Path ${env:ProgramFiles} 'Puppet Labs\Puppet\bin\puppet.bat'
    if (-not (Test-Path $puppet)) {
        $puppet = Join-Path ${env:ProgramFiles} 'Puppet Labs\Puppet\bin\puppet'
    }
    @"
class { 'win_packages::drivers::nvidia_grid':
  driver_name  => '$driverName',
  display_name => 'NVIDIA Offline Cache Test',
  srcloc       => 'https://127.0.0.1:9/unreachable',
}
"@ | Set-Content -Path $manifestPath -NoNewline -Encoding ASCII
    & $puppet apply `
        '--color=false' `
        '--modulepath=C:\ronin_puppet\modules;C:\ronin_puppet\r10k_modules' `
        '--detailed-exitcodes' `
        $manifestPath *> $puppetLog
    $puppetExitCode = $LASTEXITCODE
    if ($puppetExitCode -notin 0, 2) {
        $puppetOutput = Get-Content -Path $puppetLog -Raw -ErrorAction SilentlyContinue
        if ($puppetOutput) {
            $puppetOutput -replace "$([char]27)\[[0-9;]*[A-Za-z]", '' | Write-Output
        }
        exit $puppetExitCode
    }
} finally {
    Remove-Item -Path $driverPath, $manifestPath, $puppetLog -Force -ErrorAction SilentlyContinue
}
