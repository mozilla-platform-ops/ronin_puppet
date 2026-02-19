$ErrorActionPreference = 'Stop'

$LogDir  = 'C:\ProgramData\xperf'
$LogFile = Join-Path $LogDir 'xperf_task_acl.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Log([string]$m) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
  $line = "$ts $m"
  $line
  try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch { }
}

# First, be permissive to prove it works:
# SYSTEM + Admins full; Users full (tighten later).
$Sddl = 'D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FA;;;BU)'

$Names = @(
  'xperf_kernel_trace_start',
  'xperf_kernel_trace_stop'
)

function Get-FullTaskPath([string]$taskName) {
  $t = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -ieq $taskName } | Select-Object -First 1
  if (-not $t) { return $null }
  return ("{0}{1}" -f $t.TaskPath, $t.TaskName)  # TaskPath includes trailing '\'
}

function Set-AclViaScheduledTasks([string]$taskName, [string]$sddl) {
  # Requires ScheduledTasks module (present on Win 10/11)
  Log "Set-AclViaScheduledTasks :: $taskName"
  Set-ScheduledTask -TaskName $taskName -SecurityDescriptorSddl $sddl -ErrorAction Stop | Out-Null
}

function Set-AclViaCom([string]$taskPath, [string]$sddl) {
  Log "Set-AclViaCom :: $taskPath"
  $svc = New-Object -ComObject 'Schedule.Service'
  $svc.Connect()

  $folderPath = Split-Path $taskPath -Parent
  if ([string]::IsNullOrWhiteSpace($folderPath)) { $folderPath = '\' }
  $folder = $svc.GetFolder($folderPath)

  $task = $folder.GetTask($taskPath)

  # DACL only = 0x4 (TASK_SECURITY_DACL)
  $cur = $task.GetSecurityDescriptor(0xF)
  Log "COM current SDDL :: $cur"

  $task.SetSecurityDescriptor($sddl, 0x4)

  $ver = $task.GetSecurityDescriptor(0xF)
  Log "COM new SDDL :: $ver"
  if ($ver -ne $sddl) { throw "COM verify failed for $taskPath" }
}

try {
  foreach ($name in $Names) {
    Log "BEGIN :: $name"

    $full = Get-FullTaskPath $name
    if (-not $full) {
      throw "Task not found: $name (Get-ScheduledTask couldn’t locate it)"
    }
    Log "Resolved task path :: $full"

    # Try ScheduledTasks path first (most reliable under SYSTEM)
    try {
      Set-AclViaScheduledTasks -taskName $name -sddl $Sddl
      Log "OK :: Set-ScheduledTask applied :: $name"
      continue
    } catch {
      Log "WARN :: Set-ScheduledTask failed :: $name :: $($_.Exception.Message)"
    }

    # Fallback to COM
    Set-AclViaCom -taskPath $full -sddl $Sddl
    Log "OK :: COM applied :: $full"
  }

  Log "DONE"
  exit 0
}
catch {
  Log ("FATAL :: {0}" -f $_.Exception.ToString())
  exit 1
}
