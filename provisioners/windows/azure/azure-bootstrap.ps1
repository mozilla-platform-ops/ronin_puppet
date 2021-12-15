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

function Set-RoninRegOptions {
  param (
    [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
    [string] $ronnin_key = "$mozilla_key\ronin_puppet",
    [string] $source_key = "$ronnin_key\source",
    [string] $image_provisioner,
    [string] $workerType,
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Revision
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    If(!( test-path "$ronnin_key")) {
      New-Item -Path HKLM:\SOFTWARE -Name Mozilla -force
      New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet -force
    }

    New-Item -Path $ronnin_key -Name source -force
    New-ItemProperty -Path "$ronnin_key" -Name 'image_provisioner' -Value "$image_provisioner" -PropertyType String
    New-ItemProperty -Path "$ronnin_key" -Name 'workerType' -Value "$workerType" -PropertyType String
    $role = $workerType -replace '-',''
    New-ItemProperty -Path "$ronnin_key" -Name 'role' -Value "$role" -PropertyType String
    Write-Log -message  ('{0} :: Node workerType set to {1}' -f $($MyInvocation.MyCommand.Name), ($workerType)) -severity 'DEBUG'

    New-ItemProperty -Path "$ronnin_key" -Name 'inmutable' -Value 'false' -PropertyType String
    New-ItemProperty -Path "$ronnin_key" -Name 'runtosuccess' -Value 'true' -PropertyType String
    New-ItemProperty -Path "$ronnin_key" -Name 'last_run_exit' -Value '0' -PropertyType Dword
    New-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'setup' -PropertyType String


    New-ItemProperty -Path "$source_key" -Name 'Organisation' -Value "$src_Organisation" -PropertyType String
    New-ItemProperty -Path "$source_key" -Name 'Repository' -Value "$src_Repository" -PropertyType String
    New-ItemProperty -Path "$source_key" -Name 'Revision' -Value "$src_Revision" -PropertyType String

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

function AzInstall-Prerequ {
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
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    # testing only
    # Invoke-WebRequest -Uri  $ext_src/391.81_grid_win10_server2016_64bit_international.zip  -UseBasicParsing -OutFile $work_dir\391.81_grid_win10_server2016_64bit_international.zip

    New-Item -path $work_dir -ItemType "directory"
    Set-location -path $work_dir
    Invoke-WebRequest -Uri  $ext_src/BootStrap.zip  -UseBasicParsing -OutFile $work_dir\BootStrap.zip
    Expand-Archive -path $work_dir\BootStrap.zip -DestinationPath $env:systemdrive\
    Set-location -path $local_dir
    remove-item $work_dir   -Recurse  -force

    Start-Process $local_dir\$git /verysilent -wait
    Write-Log -message  ('{0} :: Git installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$git")) -severity 'DEBUG'
    Start-Process  msiexec -ArgumentList "/i", "$local_dir\$puppet", "/passive" -wait
    Write-Log -message  ('{0} :: Puppet installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$puppet")) -severity 'DEBUG'

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

Function Clone-Ronin {
  param (
    [string] $sourceOrg = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Organisation,
    [string] $sourceRepo = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Repository,
    [string] $sourceRev = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Revision,
    [string] $ronin_repo = "$env:systemdrive\ronin"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    If((test-path $env:systemdrive\ronin)) {
        Remove-Item -Recurse -Force $env:systemdrive\ronin
    }
    If(!(test-path $env:systemdrive\ronin)) {
      git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
      $git_exit = $LastExitCode
      if ($git_exit -eq 0) {
        cd $ronin_repo
        $git_hash = (git rev-parse --verify HEAD)
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
        Write-Log -message  ('{0} :: Cloning from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
      } else {
        Write-Log -message  ('{0} :: Git clone failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
        DO {
          Start-Sleep -s 15
          git clone  --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
          $git_exit = $LastExitCode
        } Until ( $git_exit -eq 0)
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

Function AzRonin-PreRun {
  param (
    [string] $nodes_def_src  = "$env:systemdrive\BootStrap\nodes.pp",
    [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes.pp",
    [string] $bootstrap_dir = "$env:systemdrive\BootStrap\",
    [string] $secret_src = "$env:systemdrive\BootStrap\secrets\",
    [string] $secrets = "$env:systemdrive\ronin\data\secrets\",
    [String] $sentry_reg = "HKLM:SYSTEM\CurrentControlSet\Services",
    [string] $workerType = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").workerType,
    [string] $role = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").role,
    [string] $sourceOrg = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Organisation,
    [string] $sourceRepo = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Repository,
    [string] $sourceRev = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Revision,
    [string] $winlogon = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"

  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    if (!(test-path $env:systemdrive\ronin)) {
        Clone-Ronin
    }

    if (!(Test-path $nodes_def)) {
      Copy-item -path $nodes_def_src -destination $nodes_def -force
      (Get-Content -path $nodes_def) -replace 'roles::role', "roles::$role" | Set-Content $nodes_def
    }
    if (!(Test-path $secrets)) {
      Copy-item -path $secret_src -destination $secrets -recurse -force
    }

    Set-ItemProperty -Path "$sentry_reg\SecurityHealthService" -name "start" -Value '4' -Type Dword
    Set-ItemProperty -Path "$sentry_reg\sense" -name "start" -Value '4' -Type Dword

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

function AzBootstrap-Puppet {
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
        write-host LOOK HERE for GIT checkout exit!!!!
        write-host git exit was $git_exit
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
          Write-Log -message  ('{0} :: Puppet apply failed 1st run.  ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          Move-StrapPuppetLogs
          exit 0
        } elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Move-StrapPuppetLogs
          exit 1
        }
      } elseif  (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
        Write-Log -message  ('{0} :: Puppet apply successful. Waiting on Cloud-Image-Builder pickup' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Move-StrapPuppetLogs
        exit 0
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $last_exit
        Start-sleep -s 300
        Move-StrapPuppetLogs
        exit 1
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

# Ensuring scripts can run uninhibited
# This is noisey but works
# Powershell Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue > $null

$workerType = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('workerType') })[0].value
$src_Organisation = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('sourceOrganisation') })[0].value
$src_Repository = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('sourceRepository') })[0].value
$src_Revision = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('sourceRevision') })[0].value
$image_provisioner = 'azure'

If(test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet') {
    $stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
}
If(!(test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet')) {
    Setup-Logging -DisableNameChecking
    Set-RoninRegOptions -DisableNameChecking -workerType $workerType -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision -image_provisioner $image_provisioner
    AzInstall-Prerequ -DisableNameChecking
    exit 0
}
If (($stage -eq 'setup') -or ($stage -eq 'inprogress')){
    AzRonin-PreRun -DisableNameChecking
    AzBootstrap-Puppet -DisableNameChecking
    exit 0
}
If ($stage -eq 'complete') {
    Write-Log -message  ('{0} ::Bootstrapping appears complete'  -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    exit 0
}
