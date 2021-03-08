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
function ARM64-Install-Prerequ {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $work_dir = "$env:systemdrive\scratch",
    [string] $git = "Git-2.18.0-86-bit.exe",
    [string] $puppet = "puppet-agent-6.0.0-x86.msi"
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

    Start-Process $local_dir\$git /verysilent -wait
    Write-Log -message  ('{0} :: Git installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$git")) -severity 'DEBUG'
    Start-Process  msiexec -ArgumentList "/i", "$local_dir\$puppet", "/passive" -wait
    Write-Log -message  ('{0} :: Puppet installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$puppet")) -severity 'DEBUG'

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Set-EnvironmentVariable
{
  param
  (
    [Parameter(Mandatory=$true)]
    [String]
    $Name,

    [Parameter(Mandatory=$true)]
    [String]
    $Value,

    [Parameter(Mandatory=$true)]
    [EnvironmentVariableTarget]
    $Target
  )
  [System.Environment]::SetEnvironmentVariable($Name, $Value, $Target)
}


function ARM64-Set-Options {
  param (
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
	Set-EnvironmentVariable -Name image_provisioner -Value $image_provisioner -Target global
	Set-EnvironmentVariable -Name workerType -Value $workerType -Target global
	$role = $workerType -replace '-',''
	Set-EnvironmentVariable -Name role -Value $role -Target global

	Set-EnvironmentVariable -Name ronin_Organisation -Value $src_Organisation -Target global
	Set-EnvironmentVariable -Name ronin_Repository -Value $src_Repository -Target global
	Set-EnvironmentVariable -Name ronin_Revision -Value $src_Revision -Target global

	Set-EnvironmentVariable -Name inmutable -Value 'false' -Target global
	Set-EnvironmentVariable -Name runtosuccess -Value 'true' -Target global
	Set-EnvironmentVariable -Name ronin_last_run_exit -Value 0 -Target global
	Set-EnvironmentVariable -Name bootstrap_stage -Value 'setup' -Target global
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

Function ARM64-Clone-Ronin {
  param (
    [string] $sourceOrg = $env:ronin_Organisation,
    [string] $sourceRepo = $env:ronin_Repository,
    [string] $sourceRev = $env:ronin_Revision,
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
        $git_hash = (git rev-parse --verify HEAD)
		Set-EnvironmentVariable -Name ronin_hash -Value git_hash -Target global
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

Function ARM64-Ronin-PreRun {
  param (
    [string] $nodes_def_src  = "$env:systemdrive\BootStrap\nodes.pp",
    [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes.pp",
    [string] $bootstrap_dir = "$env:systemdrive\BootStrap\",
    [string] $secret_src = "$env:systemdrive\BootStrap\secrets\",
    [string] $secrets = "$env:systemdrive\ronin\data\secrets\",
    #############[String] $sentry_reg = "HKLM:SYSTEM\CurrentControlSet\Services",
    [string] $workerType = $env:workerType,
    [string] $role = $env:role,
    [string] $sourceOrg = $env:ronin_Organisation,
    [string] $sourceRepo = $env:ronin_Repository,
    [string] $sourceRev = $env:ronin_Revision,
    #############[string] $winlogon = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"

  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    Clone-Ronin

    if (!(Test-path $nodes_def)) {
      Copy-item -path $nodes_def_src -destination $nodes_def -force
      (Get-Content -path $nodes_def) -replace 'roles::role', "roles::$role" | Set-Content $nodes_def
    }
    if (!(Test-path $secrets)) {
      Copy-item -path $secret_src -destination $secrets -recurse -force
    }

    ########Set-ItemProperty -Path "$sentry_reg\SecurityHealthService" -name "start" -Value '4' -Type Dword
    ########Set-ItemProperty -Path "$sentry_reg\sense" -name "start" -Value '4' -Type Dword

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Bootstrap-Puppet {
  param (
    [int] $exit,
    [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
    [int] $last_exit = $env:ronin_last_run_exit,
    [string] $run_to_success = $env:runtosuccess,
    ####################[string] $restorable = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").restorable,
    [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
    [string] $puppetfile = "$env:systemdrive\ronin\Puppetfile",
    [string] $logdir = "$env:systemdrive\logs",
    [string] $datetime = (get-date -format yyyyMMdd-HHmm),
    [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid",
    [string] $sourceOrg = $env:ronin_last_run_exit,
    [string] $sourceRepo = $env:ronin_Repository,
    [string] $sourceRev = $env:ronin_Revision,
    ###################[string] $restore_needed = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").restore_needed,
    [string] $stage = $env:bootstrap_stage
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    Set-Location $env:systemdrive\ronin
    If(!(test-path $logdir\old))  {
      New-Item -ItemType Directory -Force -Path $logdir\old
    }
    If ($stage -eq "inprogress") {
      git pull https://github.com/$sourceOrg/$sourceRepo $sourceRev
      $git_exit = $LastExitCode
      if ($git_exit -eq 0) {
        $git_hash = (git rev-parse --verify HEAD)
		Set-EnvironmentVariable -Name ronin_hash -Value git_hash -Target global
        Write-Log -message  ('{0} :: Checking/pulling updates from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
      } else {
        Write-Log -message  ('{0} :: Git pull failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
        Move-item -Path $ronin_repo\manifests\nodes.pp -Destination $env:TEMP\nodes.pp
        Move-item -Path $ronin_repo\data\secrets\vault.yaml -Destination $env:TEMP\vault.yaml
        Remove-Item -Recurse -Force $ronin_repo
        Start-Sleep -s 2
        git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
        Move-item -Path $env:TEMP\nodes.pp -Destination $ronin_repo\manifests\nodes.pp
        Move-item -Path $env:TEMP\vault.yaml -Destination $ronin_repo\data\secrets\vault.yaml
      }
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
		  Set-EnvironmentVariable -Name ronin_last_run_exit -Value $puppet_exit -Target global
          shutdown ('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        } elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
		  Set-EnvironmentVariable -Name ronin_last_run_exit -Value $puppet_exit -Target global
          ##########if ( $restorable -like "yes") {
            ########if ( $restore_needed -like "false") {
                #########Set-ItemProperty -Path "$ronnin_key" -name  restore_needed -value "puppetize_failed"
            #########} else {
                ##########Start-Restore
            ##########}
          }
          Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 300
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif  (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
		Set-EnvironmentVariable -Name ronin_last_run_exit -Value $puppet_exit -Target global
	    Set-EnvironmentVariable -Name bootstrap_stage -Value 'complete' -Target global
        shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap complete', '-f', '-d', '4:5')
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
	    Set-EnvironmentVariable -Name ronin_last_run_exit -Value $puppet_exit -Target global
        Start-sleep -s 600
        shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
