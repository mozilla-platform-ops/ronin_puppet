# scripts\check_thermal_hp.ps1
# Uses: Win32_PerfFormattedData_Counters_ThermalZoneInformation.HighPrecisionTemperature
# Units are commonly Kelvin*10 (tenths Kelvin), convert to Celsius: (K10/10) - 273.15

function Exit-With([int]$code, [string]$msg) {
  Write-Output $msg
  exit $code
}

try {
  $items = Get-CimInstance -Namespace root/cimv2 -ClassName Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction Stop
} catch {
  Exit-With 3 "UNKNOWN - Failed to query ThermalZoneInformation: $($_.Exception.Message)"
}

if (-not $items) {
  Exit-With 3 "UNKNOWN - No instances returned from ThermalZoneInformation"
}

$readings = @()
foreach ($i in $items) {
  $raw = $i.HighPrecisionTemperature
  if ($null -ne $raw) {
    $c = [Math]::Round(($raw / 10.0) - 273.15, 1)
    $name = if ($i.Name) { $i.Name } else { "zone" }
    $readings += [pscustomobject]@{ Name = $name; C = $c }
  }
}

if ($readings.Count -eq 0) {
  Exit-With 3 "UNKNOWN - No HighPrecisionTemperature values found"
}

$max = ($readings | Measure-Object -Property C -Maximum).Maximum
$zones = ($readings | ForEach-Object { "$($_.Name)=$($_.C)C" }) -join ", "

# No thresholds: always OK if we have data
$perf = "temp_hp_c=$max;;;0;110"
Exit-With 0 "OK - ThermalZoneInfo max ${max}C ($zones) | $perf"
