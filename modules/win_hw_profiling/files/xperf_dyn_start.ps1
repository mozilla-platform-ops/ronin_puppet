$ErrorActionPreference = 'Continue'

# ============================================================================
# xperf_dyn_start.ps1
#
# Runs as SYSTEM via the xperf_dyn_trace_start scheduled task. An unprivileged
# task user selects what to trace by writing an options file into their own
# profile BEFORE triggering this task:
#
#   <interactive-user-profile>\xperf\xperf_dyn_options.json
#
# Schema (all fields optional; missing/invalid input => built-in defaults):
#
#   {
#     "sessions": [
#       { "name": "NT Kernel Logger",
#         "on": "PROC_THREAD+LOADER+PROFILE+CSWITCH",
#         "stackwalk": "PROFILE+CSWITCH",
#         "buffersize": 1024,
#         "file": "kernel_session.etl" },
#       { "name": "usersession",
#         "on": "Microsoft-Windows-Kernel-Processor-Power:0x80+...",
#         "buffersize": 1024,
#         "file": "user_session.etl" }
#     ]
#   }
#
# SECURITY / CONTAINMENT (this file is written by an unprivileged user and
# consumed by a SYSTEM process):
#   * The ONLY executable this script ever launches is script-resolved
#     xperf.exe. The options file cannot name a program or a path to one.
#   * The script owns the flags; the file owns only the VALUES that fill the
#     -start/-on/-stackwalk/-f/-BufferSize slots. The file cannot introduce a
#     new flag or an extra argv token.
#   * xperf is invoked as `& $xperf @args` (argument array, no shell), so
#     metacharacters in a value are inert -- they are passed to xperf as a
#     single literal token, never parsed by a shell.
#   * Every value is validated (charset / integer bounds / bare filename with
#     no path separators or traversal). Any failure => that field (or the
#     whole file) is rejected and built-in defaults are used. Never fail open.
#
# Trace SCOPE is intentionally NOT restricted: developers may request any
# providers/kernel flags they need. The guarantee here is process
# containment, not option restriction.
# ============================================================================

function Get-InteractiveUserProfilePath {
  try {
    # Current interactive console user (domain-safe)
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
  # The executable is resolved by THIS script -- never from the options file.
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

  # Defense in depth: the resolved binary must actually be xperf.exe.
  if ([System.IO.Path]::GetFileName($resolved).ToLowerInvariant() -ne 'xperf.exe') { return $null }
  return $resolved
}

function WriteUserLog($log, $sev, $msg) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  try { Add-Content -Path $log -Value "$ts [$sev] $msg" -Encoding UTF8 -ErrorAction SilentlyContinue } catch { }
}

# ---- Validators. Each returns $null on rejection so the caller can default. ----

function Test-ProviderString([string]$v) {
  # xperf provider / kernel-flag / stackwalk strings: alphanumerics plus the
  # provider-expression punctuation. Deliberately excludes whitespace, quotes
  # and shell metacharacters ( & | ; < > ` \ ).
  if ([string]::IsNullOrEmpty($v)) { return $null }
  if ($v.Length -gt 4096) { return $null }
  if ($v -notmatch '^[A-Za-z0-9+:._-]+$') { return $null }
  return $v
}

function Test-SessionName([string]$v) {
  # Session names may contain spaces (e.g. "NT Kernel Logger"). Passed as a
  # single argv token, so a space is safe; still exclude shell metacharacters.
  if ([string]::IsNullOrEmpty($v)) { return $null }
  if ($v.Length -gt 64) { return $null }
  if ($v -notmatch '^[A-Za-z0-9 ._-]+$') { return $null }
  return $v
}

function Test-BufferSize($v) {
  $n = 0
  if (-not [int]::TryParse([string]$v, [ref]$n)) { return $null }
  if ($n -lt 64 -or $n -gt 65536) { return $null }
  return $n
}

function Test-EtlFileName([string]$v) {
  # Must be a bare filename confined to $outDir: no path separators, no drive,
  # no traversal. The script prepends $outDir itself.
  if ([string]::IsNullOrEmpty($v)) { return $null }
  if ($v.Length -gt 128) { return $null }
  if ($v -notmatch '^[A-Za-z0-9._-]+$') { return $null }   # excludes / \ : .. spaces
  if ($v -notmatch '\.etl$') { return $null }
  return $v
}

# ----------------------------------------------------------------------------

# Resolve output/working directory (interactive user profile preferred).
$profile = Get-InteractiveUserProfilePath
if (-not $profile) { $profile = 'C:\ProgramData\xperf' }

$outDir = Join-Path $profile 'xperf'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$log      = Join-Path $outDir 'xperf_dyn_start.log'
$optsFile = Join-Path $outDir 'xperf_dyn_options.json'

$xperf = Find-Xperf
if (-not $xperf) {
  WriteUserLog $log 'ERROR' 'xperf.exe not found (or resolved to a non-xperf binary)'
  exit 2
}
WriteUserLog $log 'INFO' ("start :: outDir={0}" -f $outDir)
WriteUserLog $log 'INFO' ("start :: xperf={0}"  -f $xperf)

# ---- Built-in defaults (mirror the fixed xperf_kernel_start.ps1) ----
$defaultSessions = @(
  [ordered]@{
    name       = 'NT Kernel Logger'
    on         = 'PROC_THREAD+LOADER+PROFILE+CSWITCH'
    stackwalk  = 'PROFILE+CSWITCH'
    buffersize = 1024
    file       = 'kernel_session.etl'
  },
  [ordered]@{
    name       = 'usersession'
    on         = 'Microsoft-Windows-Kernel-Processor-Power:0x80+Microsoft-JScript:0x3+c923f508-96e4-5515-e32c-7539d1b10504:0x6+d2d578d9-2936-45b6-a09f-30e32715f42d:0x10000+Microsoft-Antimalware-Engine'
    stackwalk  = $null
    buffersize = 1024
    file       = 'user_session.etl'
  }
)

# ---- Parse + validate the run-time options file (if present) ----
$sessions = $defaultSessions

if (Test-Path $optsFile) {
  WriteUserLog $log 'INFO' ("start :: reading options file {0}" -f $optsFile)
  try {
    $raw = Get-Content -Path $optsFile -Raw -Encoding UTF8 -ErrorAction Stop
    $cfg = $raw | ConvertFrom-Json -ErrorAction Stop

    $parsed = @()
    $ok     = $true

    if (-not $cfg.sessions) { throw "options file has no 'sessions' array" }

    foreach ($s in @($cfg.sessions)) {
      $name = Test-SessionName    ([string]$s.name)
      $on   = Test-ProviderString ([string]$s.on)
      $file = Test-EtlFileName    ([string]$s.file)
      $bs   = Test-BufferSize     $s.buffersize

      # stackwalk is optional; if present it must validate.
      $sw = $null
      if ($null -ne $s.stackwalk -and [string]$s.stackwalk -ne '') {
        $sw = Test-ProviderString ([string]$s.stackwalk)
        if ($null -eq $sw) { $ok = $false; WriteUserLog $log 'WARN' ("rejected stackwalk value for session '{0}'" -f $s.name) }
      }

      if ($null -eq $name -or $null -eq $on -or $null -eq $file -or $null -eq $bs) {
        $ok = $false
        WriteUserLog $log 'WARN' ("rejected session (name/on/file/buffersize failed validation): {0}" -f ($s | ConvertTo-Json -Compress))
        continue
      }

      $parsed += [ordered]@{ name = $name; on = $on; stackwalk = $sw; buffersize = $bs; file = $file }
    }

    if ($ok -and $parsed.Count -gt 0) {
      $sessions = $parsed
      WriteUserLog $log 'INFO' ("start :: using {0} session(s) from options file" -f $sessions.Count)
    } else {
      WriteUserLog $log 'WARN' 'options file invalid or empty after validation; using built-in defaults'
    }
  } catch {
    WriteUserLog $log 'WARN' ("failed to parse options file ({0}); using built-in defaults" -f $_.Exception.Message)
  }
} else {
  WriteUserLog $log 'INFO' 'no options file present; using built-in defaults'
}

# ---- Build the argument array. THE SCRIPT OWNS THE FLAGS. ----
# Only validated values fill the -start/-on/-stackwalk/-f/-BufferSize slots;
# the file cannot introduce a flag or an extra token.
$args = @()
foreach ($s in $sessions) {
  $etl = Join-Path $outDir $s.file
  $args += @('-start', $s.name, '-on', $s.on)
  if ($s.stackwalk) { $args += @('-stackwalk', $s.stackwalk) }
  $args += @('-f', $etl, '-BufferSize', [string]$s.buffersize)
}

WriteUserLog $log 'INFO' ("start :: invoking xperf: {0} {1}" -f $xperf, ($args -join ' '))

# No shell: each array element is one literal argv token to xperf.exe.
$out = & $xperf @args 2>&1
$rc  = $LASTEXITCODE

if ($out) { WriteUserLog $log 'DEBUG' (("xperf :: " + (($out | Out-String).Trim()))) }

if ($rc -ne 0) {
  WriteUserLog $log 'ERROR' ("start :: FAILED rc={0}" -f $rc)
  exit $rc
}

WriteUserLog $log 'INFO' 'start :: SUCCESS'
exit 0
