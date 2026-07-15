$ErrorActionPreference = 'Continue'

# ============================================================================
# xperf_dyn_stop.ps1
#
# Runs as SYSTEM via the xperf_dyn_trace_stop scheduled task. Stops the
# sessions named in the same run-time options file used by xperf_dyn_start.ps1
# and merges them into a single .etl.
#
#   <interactive-user-profile>\xperf\xperf_dyn_options.json
#
# Optional top-level "output" field names the merged .etl (default
# combined.etl). Same containment rules as the start script: ONLY xperf.exe is
# launched, invoked as `& $xperf @args` (no shell), and every value from the
# file is validated (session-name charset, bare .etl filename with no path
# separators/traversal). Missing/invalid input => built-in defaults.
# ============================================================================

function Get-InteractiveUserProfilePath {
  try {
    $user = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if (-not $user) { return $null }

    $sid = (New-Object System.Security.Principal.NTAccount($user)).
      Translate([System.Security.Principal.SecurityIdentifier]).Value

    $k = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    $p = (Get-ItemProperty -Path $k -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
    if ($p -and (Test-Path $p)) { return $p }
  } catch { }
  return $null
}

function Find-Xperf {
  $resolved = $null

  $cmd = Get-Command xperf -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { $resolved = $cmd.Source }

  if (-not $resolved) {
    $candidates = @(
      "$env:ProgramFiles(x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe",
      "$env:ProgramFiles\Windows Kits\10\Windows Performance Toolkit\xperf.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $resolved = $c; break } }
  }

  if (-not $resolved) { return $null }
  if ([System.IO.Path]::GetFileName($resolved).ToLowerInvariant() -ne 'xperf.exe') { return $null }
  return $resolved
}

function WriteUserLog($log, $sev, $msg) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  try { Add-Content -Path $log -Value "$ts [$sev] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
}

function Test-SessionName([string]$v) {
  if ([string]::IsNullOrEmpty($v)) { return $null }
  if ($v.Length -gt 64) { return $null }
  if ($v -notmatch '^[A-Za-z0-9 ._-]+$') { return $null }
  return $v
}

function Test-EtlFileName([string]$v) {
  if ([string]::IsNullOrEmpty($v)) { return $null }
  if ($v.Length -gt 128) { return $null }
  if ($v -notmatch '^[A-Za-z0-9._-]+$') { return $null }
  if ($v -notmatch '\.etl$') { return $null }
  return $v
}

$profile = Get-InteractiveUserProfilePath
if (-not $profile) { $profile = 'C:\ProgramData\xperf' }

$outDir = Join-Path $profile 'xperf'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$log      = Join-Path $outDir 'xperf_dyn_stop.log'
$optsFile = Join-Path $outDir 'xperf_dyn_options.json'

$xperf = Find-Xperf
if (-not $xperf) {
  WriteUserLog $log 'ERROR' 'xperf.exe not found (or resolved to a non-xperf binary)'
  exit 2
}

# ---- Defaults mirror the fixed xperf_kernel_stop.ps1 ----
$defaultNames  = @('NT Kernel Logger', 'usersession')
$defaultOutput = 'combined.etl'

$sessionNames = $defaultNames
$outputName   = $defaultOutput

if (Test-Path $optsFile) {
  WriteUserLog $log 'INFO' ("stop :: reading options file {0}" -f $optsFile)
  try {
    $cfg = (Get-Content -Path $optsFile -Raw -Encoding UTF8 -ErrorAction Stop) | ConvertFrom-Json -ErrorAction Stop

    $names = @()
    $ok    = $true
    foreach ($s in @($cfg.sessions)) {
      $n = Test-SessionName ([string]$s.name)
      if ($null -eq $n) { $ok = $false; WriteUserLog $log 'WARN' ("rejected session name: {0}" -f $s.name); continue }
      $names += $n
    }
    if ($ok -and $names.Count -gt 0) {
      $sessionNames = $names
    } else {
      WriteUserLog $log 'WARN' 'session names invalid/empty after validation; using defaults'
    }

    if ($cfg.output) {
      $o = Test-EtlFileName ([string]$cfg.output)
      if ($null -ne $o) { $outputName = $o } else { WriteUserLog $log 'WARN' 'rejected output filename; using default' }
    }
  } catch {
    WriteUserLog $log 'WARN' ("failed to parse options file ({0}); using defaults" -f $_.Exception.Message)
  }
} else {
  WriteUserLog $log 'INFO' 'no options file present; using defaults'
}

$combinedEtl = Join-Path $outDir $outputName
$partialEtl  = "$combinedEtl.tmp"

WriteUserLog $log 'INFO' ("stop :: combinedEtl={0}" -f $combinedEtl)
if (Test-Path $partialEtl) { Remove-Item -Force $partialEtl }

# ---- Build args. Script owns the flags; file supplied only names/output. ----
$args = @()
foreach ($n in $sessionNames) { $args += @('-stop', $n) }
$args += @('-d', $partialEtl)

WriteUserLog $log 'INFO' ("stop :: invoking xperf: {0} {1}" -f $xperf, ($args -join ' '))

$out = & $xperf @args 2>&1
$rc  = $LASTEXITCODE

if ($out) { WriteUserLog $log 'DEBUG' (("xperf :: " + (($out | Out-String).Trim()))) }

if ($rc -ne 0) {
  WriteUserLog $log 'ERROR' ("stop :: FAILED rc={0}" -f $rc)
  exit $rc
}

Move-Item -Force $partialEtl $combinedEtl
WriteUserLog $log 'INFO' 'stop :: SUCCESS'
exit 0
