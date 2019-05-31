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
    Write-Host -object $message -ForegroundColor $fc
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

    Invoke-WebRequest  $ext_src/$nxlog_msi -outfile $local_dir\$nxlog_msi
    msiexec /i $local_dir\$nxlog_msi /passive
    Invoke-WebRequest  $ext_src/$nxlog_conf -outfile $nxlog_dir\conf\$nxlog_conf
    Invoke-WebRequest  $ext_src/$nxlog_pem -outfile $nxlog_dir\cert\$nxlog_pem
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Install-Prerequ {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $git = "Git-2.18.0-64-bit.exe",
    [string] $puppet = "puppet-agent-6.0.0-x64.msi"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    Invoke-WebRequest  $ext_src/$git -outfile $local_dir\$git
    Invoke-WebRequest  $ext_src/$puppet -outfile $local_dir\$puppet

    & $local_dir\$git /verysilent
    msiexec /i $local_dir\$puppet /quiet

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Name-Node {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $namefile = "bitbar_name_by_mac.txt"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    Invoke-WebRequest  $ext_src/$namefile -outfile $local_dir\$namefile
    $name_mac = (Get-content "$local_dir\$namefile"| Where-Object { $_.Contains("$mac") })
    $name = ($name_mac.trim("$mac/:"))
    if ($name -NotMatch $env:COMPUTERNAME) {
      Rename-Computer -NewName "$name"
    }
    & $local_dir\$git /verysilent
    msiexec /i $local_dir\$puppet /quiet

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
    [string] $workerType = 'gecko-t-win10-64-ref-hw',
    [string] $src_Organisation = 'markcor',
    [string] $src_Repository = 'ronin_puppet',
    [string] $src_Revision = 'bug1555027'
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    New-Item -Path HKLM:\SOFTWARE -Name Mozilla –Force
    New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet –Force
    New-Item -Path $ronnin_key -Name source –Force

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

    If(!(test-path $env:systemdrive\ronin)) {
      git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
      $git_exit = $LastExitCode
      if ($git_exit -eq 0) {
        $git_hash = (git rev-parse --verify HEAD)
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
        Write-Log -message  ('{0} :: Cloning from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
      } else {
        Write-Log -message  ('{0} :: Git clone failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
        DO {
          Start-Sleep -s 60
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
Function Ronin-PreRun {
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

    Clone-Ronin

    if (!(Test-path $nodes_def)) {
      Copy-item -path $nodes_def_src -destination $nodes_def -force
      write-host here
      write-host $workerType
      (Get-Content -path $nodes_def) -replace 'roles::role', "roles::$role" | Set-Content $nodes_def
    }
    if (!(Test-path $secrets)) {
      Copy-item -path $secret_src -destination $secrets -recurse -force
    }

    Set-ItemProperty -Path "$sentry_reg\SecurityHealthService" -name "start" -Value '4' -Type Dword
    Set-ItemProperty -Path "$sentry_reg\sense" -name "start" -Value '4' -Type Dword

    Invoke-WebRequest https://raw.githubusercontent.com/$sourceOrg/$sourceRepo/$sourceRev/provisioners/windows/$role-bootstrap.ps1 -OutFile "$env:systemdrive\BootStrap\$role-bootstrap-src.ps1"
    Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\$role-bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\$role-bootstrap.ps1
    Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\$role-bootstrap.ps1" /sc onstart /RL HIGHEST /f

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Bootstrap-Puppet {
  param (
    [int] $exit,
    [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
    [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
    [string] $run_to_success = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").runtosuccess,
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
    [string] $stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
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
        Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
        Write-Log -message  ('{0} :: Checking/pulling updates from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
      } else {
        Write-Log -message  ('{0} :: Git pull failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
        DO {
          Start-Sleep -s 60
          git pull https://github.com/$sourceOrg/$sourceRepo $sourceRev
          $git_exit = $LastExitCode
        } Until ( $git_exit -eq 0)
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
    puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $logdir\$datetime-bootstrap-puppet.log
    [int]$puppet_exit = $LastExitCode

    if ($run_to_success -eq 'true') {
      if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
        if($last_exit -eq 0) {
          Write-Log -message  ('{0} :: Puppet apply failed.  ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronnin_key" -name last_exit -type  dword -value $puppet_exit
          shutdown ('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        } elseif ($last_exit -ne 0){
          Write-Log -message  ('{0} :: Puppet apply failed multiple times. Will attempt again in 600 seconds.  ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronnin_key" -name last_exit -type  dword -value $puppet_exit
          Write-Log -message  ('{0} :: Puppet apply failed. Waiting 10 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 600
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif  (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_exit -type  dword -value $puppet_exit
        Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
        shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap complete', '-f', '-d', '4:5')
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_exit -type  dword -value $last_exit
        Start-sleep -s 600
        shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
Function Bootstrap-CleanUp {
  param (
    [string] $bootstrapdir  = "$env:systemdrive\BootStrap\"

  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
  Write-Log -message  ('{0} :: Bootstrap has completed. Removing schedule task and directory' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  Remove-Item -Recurse -Force $bootstrapdir
  Schtasks /delete /tn bootstrap /f

  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

If(test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet') {
  $stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
}
If(!(test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet')) {
  Setup-Logging
  Install-Prerequ
  Name-Node
  Set-RoninRegOptions
  shutdown @('-r', '-t', '0', '-c', 'Reboot; Logging setup, registry setup, and node renamed', '-f', '-d', '4:5')
}
If ($stage -ne 'complete') {
  Ronin-PreRun
  Bootstrap-Puppet
}
If ($stage -eq 'complete') {
  Bootstrap-CleanUp
}
