# scripts\worker_pool_id.ps1
param(
  [string]$SubKey = "SOFTWARE\Mozilla\ronin_puppet",
  [string]$ValueName = "worker_pool_id"
)

function Out-And-Exit([int]$code, [string]$msg) {
  Write-Output $msg
  exit $code
}

$views = @(
  [Microsoft.Win32.RegistryView]::Registry64,
  [Microsoft.Win32.RegistryView]::Registry32
)

foreach ($view in $views) {
  try {
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
    $key  = $base.OpenSubKey($SubKey)
    if ($null -ne $key) {
      $val = $key.GetValue($ValueName, $null)
      if ($null -ne $val -and -not [string]::IsNullOrWhiteSpace([string]$val)) {
        Out-And-Exit 0 "OK - $ValueName=$val"
      }
    }
  } catch {
    # ignore and try next view
  }
}

Out-And-Exit 3 "UNKNOWN - Could not read HKLM:\$SubKey\$ValueName (32/64-bit views)"
