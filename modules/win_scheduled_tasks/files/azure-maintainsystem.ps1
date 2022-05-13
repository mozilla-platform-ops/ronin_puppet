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

function Puppet-Run {
  param (
    [int] $exit,
    [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
    [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
    [string] $inmutable = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").inmutable,
    [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
    [string] $logdir = "$env:systemdrive\logs",
    [string] $fail_dir = "$env:systemdrive\fail_logs",
    [string] $log_file = "$datetime-puppetrun.log",
    [string] $roninKey = "HKLM:\SOFTWARE\Mozilla\ronin_puppet",
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

    # Ensure worker pool ID matches what was provisioned.
    # So Puppet can update config files as needed.
    Write-Log -message  ('{0} :: Updating worker pool ID for final Puppet run' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $worker_pool_id = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('worker-pool-id') })[0].value
    Set-ItemProperty -Path "$roninKey" -Name 'worker_pool_id' -Value "$worker_pool_id" -ErrorAction SilentlyContinue

    # r10k not currently in use. leaving in place because it may change in the future
    # Write-Log -message  ('{0} :: Installing Puppetfile .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'i
    # R10k puppetfile install --moduledir=r10k_modules
    # Needs to be removed from path or a wrong puppet file will be used
    $env:path = ($env:path.Split(';') | Where-Object { $_ -ne "$env:programfiles\Puppet Labs\Puppet\puppet\bin" }) -join ';'
    If(!(test-path $fail_dir))  {
        New-Item -ItemType Directory -Force -Path $fail_dir
    }
    Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
    Write-Log -message  ('{0} :: Initiating Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $logdir\$log_file
    [int]$puppet_exit = $LastExitCode

    if ($run_to_success -eq 'true') {
      if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
        if($last_exit -eq 0) {
          Write-Log -message  ('{0} :: Puppet apply failed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronninKey" -name "last_exit" -value "$puppet_exit"
          Remove-Item $lock -ErrorAction SilentlyContinue
          # If the Puppet run fails send logs to papertrail
          # Nxlog watches $fail_dir for files names *-puppetrun.log
          Move-Item $logdir\$log_file -Destination $fail_dir
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        } elseif ($last_exit -ne 0){
          Set-ItemProperty -Path "$ronninKey" -name "last_exit" -value "$puppet_exit"
          Remove-Item $lock
          Move-Item $logdir\$log_file -Destination $fail_dir
          Write-Log -message  ('{0} :: Puppet apply failed. Waiting 10 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 600
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronninKey" -name "last_exit" -value "$puppet_exit"
        Remove-Item -path $lock
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name inmutable -value true
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronninKey" -name "last_exit" -value "$last_exit"
        Move-Item $logdir\$log_file -Destination $fail_dir
        Remove-Item -path $lock
        shutdown @('-r', '-t', '600', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

function Test-VolumeExists {
  param (
    [char[]] $driveLetter
  )
  if (Get-Command -Name 'Get-Volume' -ErrorAction 'SilentlyContinue') {
    return (@(Get-Volume -DriveLetter $driveLetter -ErrorAction 'SilentlyContinue').Length -eq $driveLetter.Length)
  }
  # volume commandlets are unavailable on windows 7, so we use wmi to access volumes here.
  return (@($driveLetter | % { Get-WmiObject -Class Win32_Volume -Filter ('DriveLetter=''{0}:''' -f $_) -ErrorAction 'SilentlyContinue' }).Length -eq $driveLetter.Length)
}
function AzMount-DiskTwo {
# Starting with disk 2 for now
# Azure packer images does have a disk 1 labled ad temp storage
# Maybe use that in the future
  param (
    [string] $lock = 'C:\dsc\in-progress.lock'
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    if ((Test-VolumeExists -DriveLetter 'Y') -and (Test-VolumeExists -DriveLetter 'Z')) {
      Write-Log -message ('{0} :: skipping disk mount (drives y: and z: already exist).' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
    } else {
      $pagefileName = $false
      Get-WmiObject Win32_PagefileSetting | ? { !$_.Name.StartsWith('c:') } | % {
        $pagefileName = $_.Name
        try {
          $_.Delete()
          Write-Log -message ('{0} :: page file: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), $pagefileName) -severity 'INFO'
        }
        catch {
          Write-Log -message ('{0} :: failed to delete page file: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $pagefileName, $_.Exception.Message) -severity 'ERROR'
        }
      }
      if (Get-Command -Name 'Clear-Disk' -errorAction SilentlyContinue) {
        try {
          Clear-Disk -Number 2 -RemoveData -Confirm:$false
          # Clear-Disk -Number 1 -RemoveData -Confirm:$false
          Write-Log -message ('{0} :: disk 1 partition table cleared.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }
        catch {
          Write-Log -message ('{0} :: failed to clear partition table on disk 1. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
        }
      } else {
        Write-Log -message ('{0} :: partition table clearing skipped on unsupported os' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      }
      if (Get-Command -Name 'Initialize-Disk' -errorAction SilentlyContinue) {
        try {
          Initialize-Disk -Number 2 -PartitionStyle MBR
          # Initialize-Disk -Number 1 -PartitionStyle MBR
          Write-Log -message ('{0} :: disk 1 initialized.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }
        catch {
          Write-Log -message ('{0} :: failed to initialize disk 1. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
        }
      } else {
        Write-Log -message ('{0} :: disk initialisation skipped on unsupported os' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      }
      if (Get-Command -Name 'New-Partition' -errorAction SilentlyContinue) {
        try {
          New-Partition -DiskNumber 2 -Size 20GB -DriveLetter Y
          # New-Partition -DiskNumber 1 -Size 20GB -DriveLetter Y
          Format-Volume -FileSystem NTFS -NewFileSystemLabel cache -DriveLetter Y -Confirm:$false
          Write-Log -message ('{0} :: cache drive Y: formatted.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }
        catch {
          Write-Log -message ('{0} :: failed to format cache drive Y:. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
        }
        try {
          New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter Z
          # New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter Z
          Format-Volume -FileSystem NTFS -NewFileSystemLabel task -DriveLetter Z -Confirm:$false
          Write-Log -message ('{0} :: task drive Z: formatted.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }
        catch {
          Write-Log -message ('{0} :: failed to format task drive Z:. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
        }
      } else {
        Write-Log -message ('{0} :: partitioning skipped on unsupported os' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      }
    }
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
            [Environment]::SetEnvironmentVariable("COMPUTERNAME", "$instanceName", "Machine")
            $env:COMPUTERNAME = $instanceName
            Rename-Computer -NewName $instanceName -force
            # Don't waste time/money on rebooting to pick up name change
            # shutdown @('-r', '-t', '0', '-c', 'Reboot; Node renamed to match tags', '-f', '-d', '4:5')
            return
        } else {
            Write-Log -message  ('{0} :: Name has not change and is {1}' -f $($MyInvocation.MyCommand.Name), ($env:computername)) -severity 'DEBUG'
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

$managed_by = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('managed-by') })[0].value
$mozilla_key = "HKLM:\SOFTWARE\Mozilla"
$ronin_key = "$mozilla_key\ronin_puppet"
$bootstrap_stage =  (Get-ItemProperty -path "$ronin_key").bootstrap_stage
$hand_off_ready = (Get-ItemProperty -path "$ronin_key").hand_off_ready

If ($hand_off_ready -eq 'yes') {
    While ($managed_by -eq $null) {
        Write-Log -message  ('{0} :: Waiting for metadata availability ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Start-Sleep -Seconds 5
        $managed_by = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('managed-by') })[0].value
    }
}

$mozilla_key = "HKLM:\SOFTWARE\Mozilla"
$ronin_key = "$mozilla_key\ronin_puppet"
$bootstrap_stage =  (Get-ItemProperty -path "$ronin_key").bootstrap_stage
$hand_off_ready = (Get-ItemProperty -path "$ronin_key").hand_off_ready

# Hand_off_ready value is set by the packer manifest
# TODO: add json manifest location
If (($hand_off_ready -eq 'yes') -and ($managed_by -eq 'taskcluster')) {
  if (!(Test-VolumeExists -DriveLetter 'Y') -and !(Test-VolumeExists -DriveLetter 'Z')) {
    AzMount-DiskTwo
    Set-DriveLetters
  }
  Check-AzVM-Name
  Run-MaintainSystem
  if (((Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").inmutable) -eq 'false') {
    Puppet-Run
  }
  StartWorkerRunner
  # wait and check if GW has started
  # Followed by additional checks to ensure VM is productive if up
  start-sleep -s 900
  while($true) {
    $gw = (Get-process -name generic-worker -ErrorAction SilentlyContinue )
    if ($gw -eq $null) {
      # Wait to supress meesage if check is cuaght during a reboot.
      start-sleep -s 45
      Write-Log -message  ('{0} :: UNPRODUCTIVE: Generic-worker process not found after expected time' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      start-sleep -s 3
      shutdown @('-s', '-t', '0', '-c', 'Shutdown: Worker is unproductive', '-f', '-d', '4:5')
    } else {
      start-sleep -s 120
    }
  }
} else {
  Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  Exit-PSSession
}
