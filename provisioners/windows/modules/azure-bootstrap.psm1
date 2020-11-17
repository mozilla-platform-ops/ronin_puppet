<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'BootStrap',
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
    Write-Host  -object $message -ForegroundColor $fc
  }
}
function Setup-Logging {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $nxlog_msi = "nxlog-ce-2.10.2150.msi",
    [string] $nxlog_conf = "nxlog.conf",
    [string] $nxlog_pem  = "papertrail-bundle.pem",
    [string] $nxlog_dir   = "$env:systemdrive\Program Files (x86)\nxlog"

  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    New-Item -ItemType Directory -Force -Path $local_dir

    Invoke-WebRequest  $ext_src/$nxlog_msi -outfile $local_dir\$nxlog_msi -UseBasicParsing
    msiexec /i $local_dir\$nxlog_msi /passive
    while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
    Invoke-WebRequest  $ext_src/$nxlog_conf -outfile "$nxlog_dir\conf\$nxlog_conf" -UseBasicParsing
    while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
    Invoke-WebRequest  $ext_src/$nxlog_pem -outfile "$nxlog_dir\cert\$nxlog_pem" -UseBasicParsing
    Restart-Service -Name nxlog -force
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Install-AzPrerequ {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $work_dir = "$env:systemdrive\scratch",
    [string] $git = "Git-2.18.0-64-bit.exe",
    [string] $puppet = "puppet-agent-6.0.0-x64.msi",
    [string] $vault_file = "azure_vault_template.yaml",
    [string] $rdagent = "rdagent",
    [string] $azure_guest_agent = "WindowsAzureGuestAgent",
    [string] $azure_telemetry = "WindowsAzureTelemetryService"
    #[string] $tooltool_tok =  (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\tooltool").token
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    New-Item -path $work_dir -ItemType "directory"
    Set-location -path $work_dir
    Invoke-WebRequest -Uri  $ext_src/BootStrap.zip  -UseBasicParsing -OutFile $work_dir\BootStrap.zip
    Expand-Archive -path $work_dir\BootStrap.zip -DestinationPath $env:systemdrive\
    Set-location -path $local_dir
    remove-item $work_dir   -Recurse  -force
    # Get-AppxPackage *windowsstore* | Remove-AppxPackage

    Start-Process $local_dir\$git /verysilent -wait
    Write-Log -message  ('{0} :: Git installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$git")) -severity 'DEBUG'
    Start-Process  msiexec -ArgumentList "/i", "$local_dir\$puppet", "/passive" -wait
    Write-Log -message  ('{0} :: Puppet installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$puppet")) -severity 'DEBUG'

    # net stop $rdagent
    #net stop $azure_guest_agent
    #net stop $azure_telemetry

    # sc delete $rdagent3
    #sc config "$azure_guest_agent" start= disabled
    #sc config "$azure_telemetry" start= disabled

    #sc delete $azure_guest_agent
    #sc delete $azure_telemetry

    # May not be needed. If not this can be removed in the future
    #Invoke-WebRequest -Uri  $ext_src/$vault_file  -UseBasicParsing -OutFile $local_dir\$vault_file
    #New-Item -ItemType Directory -Force -Path $local_dir\secrets
    #(Get-Content -path $local_dir\$vault_file) -replace 'tooltool_token_string',"$tooltool_tok" | Set-Content -path $local_dir\secrets\vault.yaml | out-null
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Bootstrap-AzPuppet {
  param (
    [int] $exit,
    [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
    [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
    [string] $run_to_success = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").runtosuccess,
    [string] $restorable = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").restorable,
    [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
    [string] $puppetfile = "$env:systemdrive\ronin\Puppetfile",
    [string] $logdir = "$env:systemdrive\logs",
    [string] $datetime = (get-date -format yyyyMMdd-HHmm),
    [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid",
    [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
    [string] $ronnin_key = "$mozilla_key\ronin_puppet",
    [string] $sourceOrg = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Organisation,
    [string] $sourceRepo = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Repository,
    [string] $sourceRev = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Revision,
    [string] $restore_needed = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").restore_needed,
    [string] $stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage,
	[string] $deploymentID = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('deploymentId') })[0].value
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    Set-Location $env:systemdrive\ronin
    If(!(test-path $logdir\old))  {
      New-Item -ItemType Directory -Force -Path $logdir\old
    }
    $git_hash = (git rev-parse --short HEAD)
    if ($git_hash -ne $deploymentID){
      If (($stage -eq 'setup') -or ($stage -eq 'inprogress')){
        git checkout $deploymentID
        $git_exit = $LastExitCode
        if ($git_exit -eq 0) {
          Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
          Write-Log -message  ('{0} :: Setting Ronin Puppet HEAD to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
        } else {
          Write-Log -message  ('{0} :: Git checkout failed! https://github.com/{1}/{2}. Branch: {3} Head: {4}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev), ($deploymentID) ) -severity 'DEBUG'
          Move-item -Path $ronin_repo\manifests\nodes.pp -Destination $env:TEMP\nodes.pp
          Move-item -Path $ronin_repo\data\secrets\vault.yaml -Destination $env:TEMP\vault.yaml
          Remove-Item -Recurse -Force $ronin_repo
          Start-Sleep -s 2
          git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
          git checkout $deploymentID
          $git_exit = $LastExitCode
          if ($git_exit -ne 0) {
            Write-Log -message  ('{0} :: FAILED to set  Ronin Puppet HEAD to {1}! Check if deploymentID is valid. Giving up on bootstrsaping!' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
            #shutdown @('-s', '-t', '0', '-c', 'Shutdown;Bootstrapping failed on possible invalid deploymentID ', '-f', '-d', '4:5')
            exit 423
          }
          Write-Log -message  ('{0} :: Setting Ronin Puppet HEAD to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
          Move-item -Path $env:TEMP\nodes.pp -Destination $ronin_repo\manifests\nodes.pp
          Move-item -Path $env:TEMP\vault.yaml -Destination $ronin_repo\data\secrets\vault.yaml
        }
      }
    } else {
      Write-Log -message  ('{0} ::Ronin Puppet HEAD is set to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'inprogress'

    # Setting Env variabes for PuppetFile install and Puppet run
    # The ssl variables are needed for R10k
    Write-Log -message  ('{0} :: Setting Puppet enviroment.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $env:path = $env:path = "$env:programfiles\Puppet Labs\Puppet\bin;$env:path"
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

    Write-Log -message  ('{0} :: Moving old logs.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
    Write-Log -message  ('{0} :: Running Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=win_hiera.yaml --logdest $logdir\$datetime-bootstrap-puppet.log
    [int]$puppet_exit = $LastExitCode

    if ($run_to_success -eq 'true') {
      if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
        if (($last_exit -eq 0) -or ($puppet_exit -eq 2)) {
          Write-Log -message  ('{0} :: Puppet apply failed.  ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          #shutdown ('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
          #return
          #exit 2
          Move-StrapPuppetLogs
          # exit 0
          # exit 1
        } elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          # sleep 300
          #return
          #shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
          Move-StrapPuppetLogs
          # exit 0
          exit 2
        }
      } elseif  (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
        #shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap complete', '-f', '-d', '4:5')
        #Write-Log -message  ('{0} :: Puppet apply successful. Waiting on Cloud-Image-Builder pickup' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
		#return
        Move-StrapPuppetLogs
        # exit 0
        exit 2
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $last_exit
        Start-sleep -s 300
        #return
        #shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
        Move-StrapPuppetLogs
        # exit 0
        exit 2
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Move-StrapPuppetLogs {
  param (
    [string] $logdir = "$env:systemdrive\logs",
    [string] $bootstraplogdir = "$logdir\bootstrap"
  )
  New-Item -ItemType Directory -Force -Path $bootstraplogdir
  Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $bootstraplogdir -ErrorAction SilentlyContinue
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
function Mount-DiskTwo {
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
          # Clear-Disk -Number 2 -RemoveData -Confirm:$false
          Clear-Disk -Number 1 -RemoveData -Confirm:$false
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
          # Initialize-Disk -Number 2 -PartitionStyle MBR
          Initialize-Disk -Number 1 -PartitionStyle MBR
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
          # New-Partition -DiskNumber 2 -Size 20GB -DriveLetter Y
          New-Partition -DiskNumber 1 -Size 20GB -DriveLetter Y
          Format-Volume -FileSystem NTFS -NewFileSystemLabel cache -DriveLetter Y -Confirm:$false
          Write-Log -message ('{0} :: cache drive Y: formatted.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }
        catch {
          Write-Log -message ('{0} :: failed to format cache drive Y:. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
        }
        try {
          # New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter Z
          New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter Z
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
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
