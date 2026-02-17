param(
  [Parameter(Mandatory=$true)]
  [string]$GroupName
)

function Write-Log {
    param (
        [string] $message,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string] $severity = 'INFO',
        [string] $source   = 'BootStrap',
        [string] $logName  = 'Application'
    )

    $entryType = 'Information'
    $eventId   = 1

    switch ($severity) {
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information';  $eventId = 1; break }
    }

    # Best-effort event log creation (avoid terminating failures / races)
    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or
            !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        # ignore
    }

    try {
        Write-EventLog -LogName $logName -Source $source `
            -EntryType $entryType -Category 0 -EventID $eventId `
            -Message $message -ErrorAction SilentlyContinue
    } catch {
        # ignore
    }

    if ([Environment]::UserInteractive) {
        $fc = @{
            'Information'  = 'White'
            'Error'        = 'Red'
            'Warning'      = 'DarkYellow'
            'SuccessAudit' = 'DarkGray'
        }[$entryType]
        Write-Host $message -ForegroundColor $fc
    }
}

$ErrorActionPreference = 'Stop'

function Get-LocalGroupSid([string]$name) {
  $nt = New-Object System.Security.Principal.NTAccount("$env:COMPUTERNAME", $name)
  $sid = $nt.Translate([System.Security.Principal.SecurityIdentifier])
  return $sid.Value
}

try {
  $priv = 'SeSystemProfilePrivilege'
  $sid  = Get-LocalGroupSid -name $GroupName
  $sidToken = "*$sid"  # secedit stores SIDs with a leading '*'

  Write-Log -message ("xperf_profiling :: target group: {0}\{1} ({2})" -f $env:COMPUTERNAME, $GroupName, $sidToken) -severity 'DEBUG'

  $tmp = Join-Path $env:TEMP "secpol_$([Guid]::NewGuid().ToString('N'))"
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null

  $cfg = Join-Path $tmp "secpol.cfg"
  $db  = Join-Path $tmp "secpol.sdb"

  # Export current rights
  & secedit /export /cfg $cfg /areas USER_RIGHTS | Out-Null
  $lines = Get-Content -LiteralPath $cfg -Encoding Unicode

  # Find the privilege line
  $idx = ($lines | Select-String -Pattern "^$priv\s*=" -SimpleMatch).LineNumber

  if (-not $idx) {
    $lines += "$priv = $sidToken"
    $changed = $true
    Write-Log -message ("xperf_profiling :: {0} not present; creating entry" -f $priv) -severity 'INFO'
  } else {
    $i = $idx - 1
    if ($lines[$i] -notmatch [regex]::Escape($sidToken)) {
      if ($lines[$i] -match "=\s*$") {
        $lines[$i] = "$($lines[$i])$sidToken"
      } else {
        $lines[$i] = "$($lines[$i]),$sidToken"
      }
      $changed = $true
      Write-Log -message ("xperf_profiling :: adding {0} to existing {1} entry" -f $sidToken, $priv) -severity 'INFO'
    } else {
      $changed = $false
      Write-Log -message ("xperf_profiling :: {0} already includes {1}" -f $priv, $sidToken) -severity 'DEBUG'
    }
  }

  if ($changed) {
    Set-Content -LiteralPath $cfg -Value $lines -Encoding Unicode
    & secedit /configure /db $db /cfg $cfg /areas USER_RIGHTS | Out-Null
    & gpupdate /target:computer /force | Out-Null

    Write-Log -message ("xperf_profiling :: granted {0} to {1}\{2}. Logoff/logon required for users to receive the privilege." -f $priv, $env:COMPUTERNAME, $GroupName) -severity 'INFO'
  } else {
    Write-Log -message ("xperf_profiling :: no change needed for {0}" -f $priv) -severity 'INFO'
  }

  exit 0
}
catch {
  Write-Log -message ("xperf_profiling :: FATAL: {0}" -f $_.Exception.ToString()) -severity 'ERROR'
  exit 1
}
