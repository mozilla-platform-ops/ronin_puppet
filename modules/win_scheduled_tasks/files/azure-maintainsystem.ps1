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

    Set-Location "$env:systemdrive\ronin"
    git pull https://github.com/$sourceOrg/$sourceRepo $sourceRev
    $git_exit = $LastExitCode
    if ($git_exit -eq 0) {
      $git_hash = (git rev-parse --verify HEAD)
      Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
      Write-Log -message  ('{0} :: Checking/pulling updates from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
    } else {
      # Fall back to clone if pull fails
     Write-Log -message  ('{0} :: Git pull failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
     Write-Log -message  ('{0} :: Deleting old repository and cloning repository .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
	 Move-item -Path $ronin_repo\manifests\nodes.pp -Destination $env:TEMP\nodes.pp
	 Move-item -Path $ronin_repo\data\secrets\vault.yaml -Destination $env:TEMP\vault.yaml
	 Remove-Item -Recurse -Force $ronin_repo
	 Start-Sleep -s 2
	 git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
	 Move-item -Path $env:TEMP\nodes.pp -Destination $ronin_repo\manifests\nodes.pp
	 Move-item -Path $env:TEMP\vault.yaml -Destination $ronin_repo\data\secrets\vault.yaml
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
    [string] $inmutable = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").inmutable,
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
    # Do not update Ronin Repo, so that there are no chnges in configuration
    # from the time of image creation

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

    Set-Location "$env:systemdrive\ronin"

    # r10k not currently in use. leaving in place because it may change in the future
    # Write-Log -message  ('{0} :: Installing Puppetfile .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'i
    # R10k puppetfile install --moduledir=r10k_modules
    # Needs to be removed from path or a wrong puppet file will be used
    $env:path = ($env:path.Split(';') | Where-Object { $_ -ne "$env:programfiles\Puppet Labs\Puppet\puppet\bin" }) -join ';'
    Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
    Write-Log -message  ('{0} :: Initiating Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=win_hiera.yaml --logdest $logdir\$datetime-puppetrun.log
    [int]$puppet_exit = $LastExitCode

    if ($run_to_success -eq 'true') {
      if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
        if($last_exit -eq 0) {
          Write-Log -message  ('{0} :: Puppet apply failed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -value $puppet_exit
          Remove-Item $lock -ErrorAction SilentlyContinue
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        } elseif ($last_exit -ne 0){
          Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -value $puppet_exit
          Remove-Item $lock
          Write-Log -message  ('{0} :: Puppet apply failed. Waiting 10 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 600
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -value $puppet_exit
        Remove-Item -path $lock
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name inmutable -value true
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -value $last_exit
        Remove-Item -path $lock
        shutdown @('-r', '-t', '600', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Set-DriveLetters {
  param (
    [hashtable] $driveLetterMap = @{
      'E:' = 'Y:';
      'F:' = 'Z:'
    }
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    $driveLetterMap.Keys | % {
      $old = $_
      $new = $driveLetterMap.Item($_)
      if (Test-VolumeExists -DriveLetter @($old[0])) {
        $volume = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$old'"
        if ($null -ne $volume) {
          $volume.DriveLetter = $new
          $volume.Put()
          if ((Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='$new'") -and (Test-VolumeExists -DriveLetter @($new[0]))) {
            Write-Log -message ('{0} :: drive {1} assigned new drive letter: {2}.' -f $($MyInvocation.MyCommand.Name), $old, $new) -severity 'INFO'
          } else {
            Write-Log -message ('{0} :: drive {1} assignment to new drive letter: {2} using wmi, failed.' -f $($MyInvocation.MyCommand.Name), $old, $new) -severity 'WARN'
            try {
              Get-Partition -DriveLetter $old[0] | Set-Partition -NewDriveLetter $new[0]
            } catch {
              Write-Log -message ('{0} :: drive {1} assignment to new drive letter: {2} using get/set partition, failed. {3}' -f $($MyInvocation.MyCommand.Name), $old, $new, $_.Exception.Message) -severity 'ERROR'
            }
          }
        }
      }
    }
    if ((Test-VolumeExists -DriveLetter 'Y') -and (-not (Test-VolumeExists -DriveLetter 'Z'))) {
      $volume = Get-WmiObject -Class win32_volume -Filter "DriveLetter='Y:'"
      if ($null -ne $volume) {
        $volume.DriveLetter = 'Z:'
        $volume.Put()
        Write-Log -message ('{0} :: drive Y: assigned new drive letter: Z:.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
      }
    }
    $volumes = @(Get-WmiObject -Class Win32_Volume | Sort-Object { $_.Name })
    Write-Log -message ('{0} :: {1} volumes detected.' -f $($MyInvocation.MyCommand.Name), $volumes.length) -severity 'INFO'
    foreach ($volume in $volumes) {
      Write-Log -message ('{0} :: {1} {2}gb' -f $($MyInvocation.MyCommand.Name), $volume.Name.Trim('\'), [math]::Round($volume.Capacity/1GB,2)) -severity 'DEBUG'
    }
    $partitions = @(Get-WmiObject -Class Win32_DiskPartition | Sort-Object { $_.Name })
    Write-Log -message ('{0} :: {1} disk partitions detected.' -f $($MyInvocation.MyCommand.Name), $partitions.length) -severity 'INFO'
    foreach ($partition in $partitions) {
      Write-Log -message ('{0} :: {1}: {2}gb' -f $($MyInvocation.MyCommand.Name), $partition.Name, [math]::Round($partition.Size/1GB,2)) -severity 'DEBUG'
    }
  }
}
function StartWorkerRunner {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        Start-Service -Name worker-runner
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Check-AzVM-Name {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $instanceName = (((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri 'http://169.254.169.254/metadata/instance?api-version=2019-06-04').Content) | ConvertFrom-Json).compute.name
        if ($instanceName -notlike $env:computername) {
            Write-Log -message  ('{0} :: The Azure VM name is {1}' -f $($MyInvocation.MyCommand.Name), ($instanceName)) -severity 'DEBUG'
            Rename-Computer -NewName $instanceName
            # Don't waste time/money on rebooting to pick up name change
            shutdown @('-r', '-t', '0', '-c', 'Reboot; Node renamed to match tags', '-f', '-d', '4:5')
            return
        } else {
            Write-Log -message  ('{0} :: LOOK HERE! Name has not change and is {1}' -f $($MyInvocation.MyCommand.Name), ($env:computername)) -severity 'DEBUG'
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

$bootstrap_stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
$hand_off_ready = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").hand_off_ready
$managed_by = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('managed-by') })[0].value
$reboot_count_exists = Get-ItemProperty HKLM:\SOFTWARE\Mozilla\ronin_puppet reboot_count -ErrorAction SilentlyContinue
  If ( $reboot_count_exists -ne $null) {
  $previous_boots = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").reboot_count
  $new_count = $previous_boots + 1
  Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name reboot_count -value $new_count -force
}
Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
#If ($bootstrap_stage -eq 'complete') {
# Hand_off_ready value is set by the packer manifest
# TODO: add json manifest location
If (($hand_off_ready -eq 'yes') -and ($managed_by -eq 'taskcluster')) {
#If ($bootstrap_stage -eq 'complete') {
  $adminAccount = Get-WmiObject Win32_UserAccount -filter "LocalAccount=True" | ? {$_.SID -Like "S-1-5-21-*-500"}
  if($adminAccount.Disabled)
  {
    $adminAccount.Disabled = $false
    $adminAccount.Put()
  }
  # Check-AzVM-Name
  $instanceName = (((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri 'http://169.254.169.254/metadata/instance?api-version=2019-06-04').Content) | ConvertFrom-Json).compute.name
  Write-Log -message  ('{0} :: LOOK HERE! Name should be {1}' -f $($MyInvocation.MyCommand.Name), ($instanceName)) -severity 'DEBUG'
  if (!(Test-VolumeExists -DriveLetter 'Y') -and !(Test-VolumeExists -DriveLetter 'Z')) {
    Set-DriveLetters
  }
  $markcovar = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('markcovar')     })[0].value
  If ($markcovar -ne 'empty_var') {
    # nothing for now
  }
  Run-MaintainSystem
  if (((Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").inmutable) -eq 'false') {
    Puppet-Run
  }
  StartWorkerRunner
  # let worker runner perform reboots
  Exit-PSSession
} else {
  Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  Exit-PSSession
}
