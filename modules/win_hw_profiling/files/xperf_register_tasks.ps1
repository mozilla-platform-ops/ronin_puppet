param(
  [Parameter(Mandatory=$true)][string]$StartScript,
  [Parameter(Mandatory=$true)][string]$StopScript
)

$ErrorActionPreference = 'Stop'

$LogDir  = 'C:\ProgramData\xperf'
$LogFile = Join-Path $LogDir 'xperf_register_tasks.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Log([string]$m) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  $line = "$ts $m"
  $line
  try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch { }
}

function Assert-File([string]$p) {
  if (-not (Test-Path $p)) { throw "Missing file: $p" }
}

Assert-File $StartScript
Assert-File $StopScript

# IMPORTANT:
# We are not giving Users "full control" of the task (that would be a privilege escalation risk).
# We only add GR/GX so they can READ + EXECUTE (trigger).
$AceUsersRun = '(A;;GRGX;;;BU)'

$TaskStart = 'xperf_kernel_trace_start'
$TaskStop  = 'xperf_kernel_trace_stop'
$TaskPath  = '\'

$PsExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

function New-OrUpdateTask([string]$taskName, [string]$scriptPath, [string]$desc) {
  $svc = New-Object -ComObject 'Schedule.Service'
  $svc.Connect()
  $folder = $svc.GetFolder($TaskPath)

  $def = $svc.NewTask(0)

  $def.RegistrationInfo.Description = $desc

  # Settings
  $def.Settings.Enabled             = $true
  $def.Settings.AllowDemandStart    = $true
  $def.Settings.StartWhenAvailable  = $true
  $def.Settings.DisallowStartIfOnBatteries = $false
  $def.Settings.StopIfGoingOnBatteries     = $false
  $def.Settings.ExecutionTimeLimit  = 'PT0S'   # no limit
  $def.Settings.MultipleInstances   = 0        # IgnoreNew

  # Run as SYSTEM, highest
  $def.Principal.UserId    = 'SYSTEM'
  $def.Principal.LogonType = 5   # TASK_LOGON_SERVICE_ACCOUNT
  $def.Principal.RunLevel  = 1   # TASK_RUNLEVEL_HIGHEST

  # Action: run the script
  $a = $def.Actions.Create(0)    # TASK_ACTION_EXEC
  $a.Path = $PsExe
  $a.Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""

  # Register / Update
  $flags = 6 # TASK_CREATE_OR_UPDATE
  $logon = 5 # TASK_LOGON_SERVICE_ACCOUNT

  Log "RegisterTaskDefinition name=$taskName"
  $null = $folder.RegisterTaskDefinition($taskName, $def, $flags, 'SYSTEM', $null, $logon, $null)

  # Append Users Run ACE (GR/GX) without disturbing existing ACEs
  $t  = $folder.GetTask($taskName)
  $sd = $t.GetSecurityDescriptor(0xF)

  if ($sd -notmatch '\(A;;GRGX;;;BU\)') {
    $new = $sd + $AceUsersRun
    Log "Updating SDDL for $taskName (adding BUILTIN\\Users GR/GX)"
    $t.SetSecurityDescriptor($new, 0)
  } else {
    Log "SDDL already contains BUILTIN\\Users GR/GX for $taskName"
  }
}

try {
  Log "BEGIN (whoami=$(whoami))"

  New-OrUpdateTask -taskName $TaskStart -scriptPath $StartScript -desc 'Start kernel xperf trace (runs as SYSTEM).'
  New-OrUpdateTask -taskName $TaskStop  -scriptPath $StopScript  -desc 'Stop kernel xperf trace (runs as SYSTEM).'

  Log "DONE"
  exit 0
}
catch {
  Log ("FATAL: {0}" -f $_.Exception.ToString())
  exit 1
}
