# scripts\cpu_perf.ps1
# Reports:
# - cpu_perf_pct: Processor Information\% Processor Performance
# - cpu_eff_mhz: Estimated effective MHz = MaxClockSpeed(MHz) * (cpu_perf_pct/100)

function Exit-With([int]$code, [string]$msg) {
  Write-Output $msg
  exit $code
}

# --- Get % Processor Performance (prefer _Total) ---
try {
  $rows = Get-CimInstance -ClassName Win32_PerfFormattedData_Counters_ProcessorInformation -ErrorAction Stop
} catch {
  Exit-With 3 "UNKNOWN - Failed to query ProcessorInformation perf class: $($_.Exception.Message)"
}

if (-not $rows) {
  Exit-With 3 "UNKNOWN - No ProcessorInformation instances returned"
}

$totals = $rows | Where-Object { $_.Name -eq "_Total" -and $null -ne $_.PercentProcessorPerformance }
if ($totals) {
  $perfPct = ($totals | Measure-Object -Property PercentProcessorPerformance -Average).Average
  $src = "_Total"
} else {
  $vals = $rows |
    Where-Object { $_.Name -ne "_Total" -and $null -ne $_.PercentProcessorPerformance } |
    ForEach-Object { [double]$_.PercentProcessorPerformance }

  if (-not $vals -or $vals.Count -eq 0) {
    Exit-With 3 "UNKNOWN - No PercentProcessorPerformance values found"
  }

  $perfPct = ($vals | Measure-Object -Average).Average
  $src = "avg"
}

$perfPct = [Math]::Round([double]$perfPct, 1)

# --- Get a baseline MHz (use MaxClockSpeed as “nominal/reference”) ---
$baseMhz = $null
try {
  $procs = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
  if ($procs) {
    $bases = @($procs | Where-Object { $_.MaxClockSpeed -gt 0 } | ForEach-Object { [double]$_.MaxClockSpeed })
    if ($bases.Count -gt 0) {
      $baseMhz = [Math]::Round(($bases | Measure-Object -Maximum).Maximum, 0)
    }
  }
} catch {
  # If this fails we still return cpu_perf_pct only
}

# --- Derived effective MHz ---
$effMhz = $null
if ($null -ne $baseMhz) {
  $effMhz = [Math]::Round($baseMhz * ($perfPct / 100.0), 0)
}

# Perfdata
# cpu_perf_pct can exceed 100 during boost, so allow up to 300 for graphing headroom
$perfParts = @("cpu_perf_pct=$perfPct;;;0;300")
if ($null -ne $effMhz) {
  $perfParts += "cpu_eff_mhz=$effMhz;;;0;8000"
}

$msg = "OK - CPU Performance ${perfPct}% (source: $src"
if ($null -ne $baseMhz -and $null -ne $effMhz) {
  $msg += ", base=${baseMhz}MHz, eff=${effMhz}MHz"
}
$msg += ") | " + ($perfParts -join " ")

Exit-With 0 $msg