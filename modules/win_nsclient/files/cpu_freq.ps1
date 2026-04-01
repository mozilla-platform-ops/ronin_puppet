# scripts\cpu_freq.ps1
# Reports CPU frequency in MHz. OK if we can read at least one source; UNKNOWN otherwise.

function Exit-With([int]$code, [string]$msg) {
  Write-Output $msg
  exit $code
}

$freqPerf = $null
$freqWmi  = $null
$maxWmi   = $null
$notes    = @()

# 1) Perf counter (more "live" on many systems)
try {
  $counterPath = '\Processor Information(_Total)\Processor Frequency'
  $sample = (Get-Counter -Counter $counterPath -ErrorAction Stop).CounterSamples | Select-Object -First 1
  $freqPerf = [math]::Round([double]$sample.CookedValue, 0)
} catch {
  $notes += "perfmon_unavailable"
}

# 2) WMI/CIM (SMBIOS-provided MHz)
try {
  $procs = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
  if ($procs) {
    $freqs = @($procs | Where-Object { $_.CurrentClockSpeed -gt 0 } | ForEach-Object { [double]$_.CurrentClockSpeed })
    if ($freqs.Count -gt 0) {
      $freqWmi = [math]::Round(($freqs | Measure-Object -Average).Average, 0)
    }
    $maxVals = @($procs | Where-Object { $_.MaxClockSpeed -gt 0 } | ForEach-Object { [double]$_.MaxClockSpeed })
    if ($maxVals.Count -gt 0) {
      $maxWmi = [math]::Round(($maxVals | Measure-Object -Maximum).Maximum, 0)
    }
  }
} catch {
  $notes += "wmi_unavailable"
}

if ($null -eq $freqPerf -and $null -eq $freqWmi) {
  Exit-With 3 "UNKNOWN - CPU frequency unavailable (notes: $($notes -join ','))"
}

# Prefer perf counter for "current" but show both when available
$chosen = if ($null -ne $freqPerf) { $freqPerf } else { $freqWmi }
$src    = if ($null -ne $freqPerf) { "perfmon" } else { "wmi" }

# Perfdata (numeric, for later graphing)
$perfParts = @()
if ($null -ne $freqPerf) { $perfParts += "cpu_freq_perf_mhz=$freqPerf;;;0;" }
if ($null -ne $freqWmi)  { $perfParts += "cpu_freq_wmi_mhz=$freqWmi;;;0;" }
if ($null -ne $maxWmi)   { $perfParts += "cpu_max_mhz=$maxWmi;;;0;" }

$msgParts = @("OK - CPU freq ${chosen}MHz (source: $src)")
if ($null -ne $freqPerf -and $null -ne $freqWmi -and $freqPerf -ne $freqWmi) {
  $msgParts += "perf=${freqPerf}MHz wmi=${freqWmi}MHz"
}
if ($null -ne $maxWmi) { $msgParts += "max=${maxWmi}MHz" }
if ($notes.Count -gt 0) { $msgParts += "(notes: $($notes -join ','))" }

Exit-With 0 ("$($msgParts -join ' ') | $($perfParts -join ' ')")