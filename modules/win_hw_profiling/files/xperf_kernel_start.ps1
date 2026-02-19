$ErrorActionPreference = 'Continue'

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
  $cmd = Get-Command xperf -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) { return $cmd.Source }

  $candidates = @(
    "$env:ProgramFiles(x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe",
    "$env:ProgramFiles\Windows Kits\10\Windows Performance Toolkit\xperf.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}

function WriteUserLog($log, $sev, $msg) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  try { Add-Content -Path $log -Value "$ts [$sev] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
}

$profile = Get-InteractiveUserProfilePath
if (-not $profile) { $profile = 'C:\ProgramData\xperf' }

$outDir = Join-Path $profile 'xperf'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$log = Join-Path $outDir 'xperf_kernel_start.log'
$etl = Join-Path $outDir 'kernel_session.etl'

$xperf = Find-Xperf
if (-not $xperf) {
  WriteUserLog $log 'ERROR' 'xperf.exe not found'
  exit 2
}

WriteUserLog $log 'INFO'  ("start :: profile={0} etl={1}" -f $profile, $etl)

$out = & $xperf -on PROC_THREAD+LOADER+PROFILE+CSWITCH -f $etl -BufferSize 1024 2>&1
$rc  = $LASTEXITCODE
if ($out) { WriteUserLog $log 'DEBUG' (("xperf :: " + (($out | Out-String).Trim()))) }

if ($rc -ne 0) {
  WriteUserLog $log 'ERROR' ("start :: FAILED rc={0}" -f $rc)
  exit $rc
}

WriteUserLog $log 'INFO' "start :: SUCCESS"
exit 0
