# scripts\check_thermal.ps1
# Always OK if data exists; UNKNOWN if no data.

function Exit-With($code, $msg) {
  Write-Output $msg
  exit $code
}

try {
  $zones = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop
} catch {
  Exit-With 3 "UNKNOWN - Failed to query thermal zones (WMI): $($_.Exception.Message)"
}

if (-not $zones) {
  Exit-With 3 "UNKNOWN - No thermal zones returned (MSAcpi_ThermalZoneTemperature)"
}

$tempsC = @()
foreach ($z in $zones) {
  if ($null -ne $z.CurrentTemperature) {
    # Kelvin*10 -> Celsius
    $c = ($z.CurrentTemperature / 10.0) - 273.15
    $tempsC += [Math]::Round($c, 1)
  }
}

if ($tempsC.Count -eq 0) {
  Exit-With 3 "UNKNOWN - Thermal zones returned, but no temperature values"
}

$max = ($tempsC | Measure-Object -Maximum).Maximum

# No thresholds: always OK (0) if we got data.
# Perfdata included so Icinga can display/graph it if perfdata backends are enabled.
$perf = "temp_c=$max;;;0;110"
Exit-With 0 "OK - Max temp ${max}C (zones: $($tempsC -join ', ') C) | $perf"
