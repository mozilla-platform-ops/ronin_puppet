# scripts\cpu_perf.ps1
# Reports Processor Information\% Processor Performance as cpu_perf_pct (no thresholds)

function Exit-With([int]$code, [string]$msg) {
  Write-Output $msg
  exit $code
}

try {
  $rows = Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ProcessorInformation -ErrorAction Stop
} catch {
  Exit-With 3 "UNKNOWN - Failed to query ProcessorInformation perf class: $($_.Exception.Message)"
}

if (-not $rows) {
  Exit-With 3 "UNKNOWN - No ProcessorInformation instances returned"
}

# Prefer _Total if present; otherwise average all instances (excluding _Total to avoid double counting)
$totals = $rows | Where-Object { $_.Name -eq "_Total" -and $null -ne $_.PercentProcessorPerformance }
if ($totals) {
  $val = ($totals | Measure-Object -Property PercentProcessorPerformance -Average).Average
  $src = "_Total"
} else {
  $vals = $rows | Where-Object { $_.Name -ne "_Total" -and $null -ne $_.PercentProcessorPerformance } |
    ForEach-Object { [double]$_.PercentProcessorPerformance }
  if (-not $vals -or $vals.Count -eq 0) {
    Exit-With 3 "UNKNOWN - No PercentProcessorPerformance values found"
  }
  $val = ($vals | Measure-Object -Average).Average
  $src = "avg"
}

$val = [Math]::Round([double]$val, 1)

# Note: this counter can be > 100 (boosting above nominal) on some systems.
# We just report it.
$perf = "cpu_perf_pct=$val;;;0;200"
Exit-With 0 "OK - CPU Performance ${val}% (source: $src) | $perf"