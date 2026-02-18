# win_hw_profiling/files/xperf_kernel_start.ps1
$ErrorActionPreference = 'Continue'

function Get-InteractiveUserProfilePath {
  try {
    # Current interactive console user (domain-safe)
    $user = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if (-not $user) { return $null }

    $sid = (New-Object System.Security.Principal.NTAccount($user)).
      Translate([System.Security.Principal.SecurityIdentifier]).Value

    $profileReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    $profileDir = (Get-ItemProperty -Path $profileReg -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath

    if ($profileDir -and (Test-Path $profileDir)) { return $profileDir }
  } catch { }

  return $null
}

function Write-UserLog {
  param(
    [string]$Message,
    [ValidateSet('DEBUG','INFO','WARN','ERROR')]
    [string]$Severity = 'INFO'
  )

  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  $line = "{0} [{1}] {2}" -f $ts, $Severity, $Message

  # Will be set by main flow
  if ($script:LogFile) {
    try {
      Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
  }
}

$profileDir = Get-InteractiveUserProfilePath
if (-not $profileDir) { $profileDir = 'C:\ProgramData\xperf' }

$outDir = Join-Path $profileDir 'xperf'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$script:LogFile = Join-Path $outDir 'xperf_kernel_start.log'
Write-UserLog -Severity 'INFO' -Message ("start :: resolved profileDir='{0}' outDir='{1}'" -f $profileDir, $outDir)

$etl = Join-Path $outDir 'kernel_session.etl'
Write-UserLog -Severity 'INFO' -Message ("start :: invoking xperf -> {0}" -f $etl)

# Start kernel trace
$out = & xperf -on PROC_THREAD+LOADER+PROFILE+CSWITCH -f $etl -BufferSize 1024 2>&1
$rc  = $LASTEXITCODE

if ($out) { Write-UserLog -Severity 'DEBUG' -Message ("xperf output :: {0}" -f (($out | Out-String).Trim())) }

if ($rc -ne 0) {
  Write-UserLog -Severity 'ERROR' -Message ("start :: FAILED rc={0}" -f $rc)
  exit $rc
}

Write-UserLog -Severity 'INFO' -Message "start :: SUCCESS"
exit 0
