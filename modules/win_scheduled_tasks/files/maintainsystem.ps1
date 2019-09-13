<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'MaintainSystem',
    [string] $logName = 'Application'
  )
  if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
    New-EventLog -LogName $logName -Source $source
  }
  switch ($severity) {
    'DEBUG' {
      $entryType = 'SuccessAudit'
      $eventId = 2
      break
    }
    'WARN' {
      $entryType = 'Warning'
      $eventId = 3
      break
    }
    'ERROR' {
      $entryType = 'Error'
      $eventId = 4
      break
    }
    default {
      $entryType = 'Information'
      $eventId = 1
      break
    }
  }
  Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
  if ([Environment]::UserInteractive) {
    $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
    Write-Host -object $message -ForegroundColor $fc
  }
}

function Run-MaintainSystem {
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    Remove-OldTaskDirectories
    Get-ChildItem "$env:systemdrive\logs\old" -Recurse -File | Where CreationTime -lt  (Get-Date).AddDays(-7)  | Remove-Item -Force
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Remove-OldTaskDirectories {
  param (
    [string[]] $targets = @('Z:\task_*', 'C:\Users\task_*')
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    foreach ($target in ($targets | ? { (Test-Path -Path ('{0}:\' -f $_[0]) -ErrorAction SilentlyContinue) })) {
      $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.LastWriteTime })
      if ($all_task_paths.length -gt 1) {
        Write-Log -message ('{0} :: {1} task directories detected matching pattern: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths.length, $target) -severity 'INFO'
        $old_task_paths = $all_task_paths[0..($all_task_paths.Length-2)]
        foreach ($old_task_path in $old_task_paths) {
          try {
            & takeown.exe @('/a', '/f', $old_task_path, '/r', '/d', 'Y')
            & icacls.exe @($old_task_path, '/grant', 'Administrators:F', '/t')
            Remove-Item -Path $old_task_path -Force -Recurse
            Write-Log -message ('{0} :: removed task directory: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime) -severity 'INFO'
          } catch {
            Write-Log -message ('{0} :: failed to remove task directory: {1}, with last write time: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime, $_.Exception.Message) -severity 'ERROR'
          }
        }
      } elseif ($all_task_paths.length -eq 1) {
        Write-Log -message ('{0} :: a single task directory was detected at: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths[0].FullName, $all_task_paths[0].LastWriteTime) -severity 'DEBUG'
      } else {
        Write-Log -message ('{0} :: no task directories detected matching pattern: {1}' -f$($MyInvocation.MyCommand.Name), $target) -severity 'DEBUG'
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Check-RoninNodeOptions {
  param (
    [string] $inmutable =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").inmutable,
    [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    Write-Host $inmutable
    if ($inmutable -eq 'true') {
      Write-Log -message  ('{0} :: Node is set to be inmutable' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      Remove-Item -path $lock -ErrorAction SilentlyContinue
      write-host New-item -path $flagfile
      Exit-PSSession
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Check-RoninLock {
  param (
    [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    if (Test-Path $lock) {
      ruby_process = Get-Process ruby -ErrorAction SilentlyContinue
      if (ruby_process -eq $null) {
        Remove-Item $lock
        write-host shutdown @('-r', '-t', '0', '-c', 'Reboot; Lock file is present but Puppet is not running', '-f', '-d', '4:5')
      } elseif (ruby_process -neq $null) {
        Write-Log -message  ('{0} :: An instance of Puppet is currently running.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        exit
      } else {
        New-Item -Path $lock -ItemType file -Force
        Write-Log -message  ('{0} :: $lock created.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

Function UpdateRonin {
  param (
    [string] $sourceOrg,
    [string] $sourceRepo,
    [string] $sourceRev,
    [string] $ronin_repo = "$env:systemdrive\ronin"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    $sourceOrg = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Organisation' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Organisation').Organisation } else { 'mozilla-platform-ops' })
    $sourceRepo = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Repository' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Repository').Repository } else { 'ronin_puppet' })
    $sourceRev = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Revision' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Revision').Revision } else { 'master' })

    Remove-Item -Recurse -Force $ronin_repo
    Start-Sleep -s 60
    Write-Log -message  ('{0} :: Removing old Ronin repo .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
    $git_exit = $LastExitCode
    if ($git_exit -eq 0) {
      $git_hash = (git rev-parse --verify HEAD)
      Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
      Write-Log -message  ('{0} :: Cloning from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
    } else {
      # For now log and exit
     Write-Log -message  ('{0} :: Git clane failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
     Exit-PSSession
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Puppet-Run {
  param (
    [int] $exit,
    [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
    [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
    [string] $run_to_success = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").runtosuccess,
    [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
    [string] $logdir = "$env:systemdrive\logs",
    [string] $datetime = (get-date -format yyyyMMdd-HHmm),
    [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    Check-RoninNodeOptions
    Check-RoninLock
    UpdateRonin

    # Setting Env variabes for PuppetFile install and Puppet run
    # The ssl variables are needed for R10k
    Write-Log -message  ('{0} :: Setting Puppet enviroment.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $env:path = "$env:programfiles\Puppet Labs\Puppet\puppet\bin;$env:programfiles\Puppet Labs\Puppet\bin;$env:path"
    $env:SSL_CERT_FILE = "$env:programfiles\Puppet Labs\Puppet\puppet\ssl\cert.pem"
    $env:SSL_CERT_DIR = "$env:programfiles\Puppet Labs\Puppet\puppet\ssl"
    $env:FACTER_env_windows_installdir = "$env:programfiles\Puppet Labs\Puppet"
    $env:HOMEPATH = "\Users\Administrator"
    $env:HOMEDRIVE = "C:"
    $env:PL_BASEDIR = "$env:programfiles\Puppet Labs\Puppet"
    $env:PUPPET_DIR = "$env:programfiles\Puppet Labs\Puppet"
    $env:RUBYLIB = "$env:programfiles\Puppet Labs\Puppet\lib"
    $env:USERNAME = "Administrator"
    $env:USERPROFILE = "$env:systemdrive\Users\Administrator"

    Write-Log -message  ('{0} :: Installing Puppetfile .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'i
    R10k puppetfile install --moduledir=r10k_modules
    # Needs to be removed from path or a wrong puppet file will be used
    $env:path = ($env:path.Split(';') | Where-Object { $_ -ne "$env:programfiles\Puppet Labs\Puppet\puppet\bin" }) -join ';'
    Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
    Write-Log -message  ('{0} :: Initiating Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $logdir\$datetime-puppetrun.log
    [int]$puppet_exit = $LastExitCode

    if ($run_to_success -eq 'true') {
      if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
        if($last_exit -eq 0) {
          Write-Log -message  ('{0} :: Puppet apply failed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $puppet_exit
          Remove-Item $lock -ErrorAction SilentlyContinue
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        } elseif ($last_exit -ne 0){
          Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $puppet_exit
          Remove-Item $lock
          Write-Log -message  ('{0} :: Puppet apply failed. Waiting 10 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 600
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $puppet_exit
        Remove-Item -path $lock
        New-item -path $flagfile
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $last_exit
        Remove-Item -path $lock
        shutdown @('-r', '-t', '600', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

$bootstrap_stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
If ($bootstrap_stage -eq 'complete') {
  Run-MaintainSystem
  Puppet-Run
} else {
  Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  Exit-PSSession
}
