$ErrorActionPreference = "Stop"

$RegPath   = "HKLM:\SOFTWARE\Mozilla\ronin_puppet"
$ValueName = "bootstrap_stage"

try {
  $stage = (Get-ItemProperty -Path $RegPath -Name $ValueName).$ValueName
  if ([string]::IsNullOrWhiteSpace($stage)) {
    Write-Output "UNKNOWN - bootstrap_stage is empty"
    exit 3
  }

  $s = $stage.Trim().ToLowerInvariant()

  if ($s -eq "complete") {
    Write-Output "OK - bootstrap_stage=$stage"
    exit 0
  }

  if ($s -eq "inprogress" -or $s -eq "in_progress") {
    Write-Output "WARNING - bootstrap_stage=$stage"
    exit 1
  }

  Write-Output "CRITICAL - bootstrap_stage=$stage"
  exit 2
}
catch {
  Write-Output "UNKNOWN - failed to read bootstrap_stage: $($_.Exception.Message)"
  exit 3
}
