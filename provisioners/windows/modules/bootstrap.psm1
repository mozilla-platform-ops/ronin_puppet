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
function Start-LoggedProcess {
  param (
    [string] $filePath,
    [string[]] $argumentList,
    [string] $name = [IO.Path]::GetFileNameWithoutExtension($filePath),
    [string] $redirectStandardOutput = ('{0}\log\{1}.{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $name),
    [string] $redirectStandardError = ('{0}\log\{1}.{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $name)
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    try {
      if (-not (Test-Path -Path $filePath -ErrorAction SilentlyContinue)) {
        Write-Log -message ('{0} :: {1} does not map to an existing path.' -f $($MyInvocation.MyCommand.Name), $filePath) -severity 'WARN'
      }
      $process = (Start-Process -FilePath $filePath -ArgumentList $argumentList -NoNewWindow -RedirectStandardOutput $redirectStandardOutput -RedirectStandardError $redirectStandardError -PassThru)
      Wait-Process -InputObject $process # see: https://stackoverflow.com/a/43728914/68115
      if ($process.ExitCode -and $process.TotalProcessorTime) {
        Write-Log -message ('{0} :: {1} - command ({2} {3}) exited with code: {4} after a processing time of: {5}.' -f $($MyInvocation.MyCommand.Name), $name, $filePath, ($argumentList -join ' '), $process.ExitCode, $process.TotalProcessorTime) -severity 'INFO'
      } else {
        Write-Log -message ('{0} :: {1} - command ({2} {3}) executed.' -f $($MyInvocation.MyCommand.Name), $name, $filePath, ($argumentList -join ' ')) -severity 'INFO'
      }
    } catch {
      Write-Log -message ('{0} :: {1} - error executing command ({2} {3}). {4}' -f $($MyInvocation.MyCommand.Name), $name, $filePath, ($argumentList -join ' '), $_.Exception.Message) -severity 'ERROR'
    }
    $standardErrorFile = (Get-Item -Path $redirectStandardError -ErrorAction SilentlyContinue)
    if (($standardErrorFile) -and $standardErrorFile.Length) {
      Write-Log -message ('{0} :: {1} - {2}' -f $($MyInvocation.MyCommand.Name), $name, (Get-Content -Path $redirectStandardError -Raw)) -severity 'ERROR'
    }
    $standardOutputFile = (Get-Item -Path $redirectStandardOutput -ErrorAction SilentlyContinue)
    if (($standardOutputFile) -and $standardOutputFile.Length) {
      Write-Log -message ('{0} :: {1} - log: {2}' -f $($MyInvocation.MyCommand.Name), $name, $redirectStandardOutput) -severity 'INFO'
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
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

function Install-Prerequ {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $work_dir = "$env:systemdrive\scratch",
    [string] $git = "Git-2.18.0-64-bit.exe",
    [string] $puppet = "puppet-agent-6.0.0-x64.msi"
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
# As seen with the ACER laptops at bitbar individual prerequ package downloads will fail
# In this case use Install-ZipPrerequ
function Install-ZipPrerequ {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $work_dir = "$env:systemdrive\scratch",
    [string] $git = "Git-2.18.0-64-bit.exe",
    [string] $puppet = "puppet-agent-6.0.0-x64.msi"
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {

    remove-item $local_dir   -Recurse  -force
    New-Item -path $work_dir -ItemType "directory"
    Set-location -path $work_dir
    Invoke-WebRequest -Uri  $ext_src/BootStrap.zip  -UseBasicParsing -OutFile $work_dir\BootStrap.zip
    Expand-Archive -path $work_dir\BootStrap.zip -DestinationPath $env:systemdrive\
    Read-Host "Enusre c:\bootstrap\secrets\vault.yam is present, and then press eneter to continue"
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
function Install-AzPrerequ {
  param (
    [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $work_dir = "$env:systemdrive\scratch",
    [string] $git = "Git-2.18.0-64-bit.exe",
    [string] $puppet = "puppet-agent-6.0.0-x64.msi",
    [string] $vault_file = "azure_vault_template.yaml"
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

    Start-Process $local_dir\$git /verysilent -wait
    Write-Log -message  ('{0} :: Git installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$git")) -severity 'DEBUG'
    Start-Process  msiexec -ArgumentList "/i", "$local_dir\$puppet", "/passive" -wait
    Write-Log -message  ('{0} :: Puppet installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$puppet")) -severity 'DEBUG'

    # May not be needed. If not this can be removed in the future
    #Invoke-WebRequest -Uri  $ext_src/$vault_file  -UseBasicParsing -OutFile $local_dir\$vault_file
    #New-Item -ItemType Directory -Force -Path $local_dir\secrets
    #(Get-Content -path $local_dir\$vault_file) -replace 'tooltool_token_string',"$tooltool_tok" | Set-Content -path $local_dir\secrets\vault.yaml | out-null
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
      New-Item -Path HKLM:\SOFTWARE -Name Mozilla –Force
      New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet –Force
    }

    New-Item -Path $ronnin_key -Name source –Force
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
Function Bootstrap-schtasks {
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

    # This will not really do anything for the Azure script but shouldn't hurt it
    # It is needed for hardware workers
    $role = $workerType -replace '-',''

    Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
    Invoke-WebRequest https://raw.githubusercontent.com/$src_Organisation/$src_Repository/$src_Revision/provisioners/windows/$image_provisioner/$role-bootstrap.ps1 -OutFile "$env:systemdrive\BootStrap\$role-bootstrap-src.ps1" -UseBasicParsing
    Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\$role-bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\$role-bootstrap.ps1
    Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\$role-bootstrap.ps1" /sc onstart /RL HIGHEST /f
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
function Bootstrap-Puppet {
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
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          shutdown ('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        } elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          if ( $restorable -like "yes") {
            if ( $restore_needed -like "false") {
                Set-ItemProperty -Path "$ronnin_key" -name  restore_needed -value "puppetize_failed"
            } else {
                Start-Restore
            }
          }
          Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 300
          shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif  (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
        shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap complete', '-f', '-d', '4:5')
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $last_exit
        Start-sleep -s 600
        shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Generalize_Vm {
  param (
    [string] $sourceOrg,
    [string] $sourceRepo,
    [string] $sourceRev,
    [string] $vm_type,
    [string] $xml_file = "generalize.xml",
    [string] $local_xml_file = "$env:systemdrive\Windows\Temp\generalize.xml"
    )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    # Testing adding firewall rules. if this helps it should be moved into Puppet
    Set-NetConnectionProfile -Name "Network" -NetworkCategory Private
    Enable-PSRemoting -Force
    #Set-NetFirewallRule -DisplayName 'Windows Remote Management (HTTP-In)' -Enabled True
    #New-NetFirewallRule -DisplayName AzurePlatform -Direction Inbound -RemoteAddress 168.63.129.16 -Profile Any -Action Allow -EdgeTraversalPolicy Allow
    #New-NetFirewallRule -DisplayName AzurePlatform -Direction Outbound -RemoteAddress 168.63.129.16 -Profile Any -Action Allow

    Invoke-WebRequest https://raw.githubusercontent.com/$sourceOrg/$sourceRepo/$sourceRev/provisioners/windows/$vm_type/$xml_file  -outfile $local_xml_file -UseBasicParsing
    Start-LoggedProcess -filePath ('{0}\system32\sysprep\sysprep.exe' -f $env:WINDIR) -ArgumentList $(if ($workerType -match 'win7') { @('/generalize', '/shutdown', '/oobe', '/unattend:C:\Windows\Temp\generalize.xml') } else { @('/generalize', '/shutdown', '/oobe', '/quiet') }) -redirectStandardOutput 'C:\log\sysprep-generalize-shutdown-stdout.log' -redirectStandardError 'C:\log\sysprep-generalize-shutdown-stderr.log' -name 'sysprep-generalize-shutdown' # remove the /mode:vm switch if creating images for different hardware profile
  }
  # '/generalize', '/shutdown', '/oobe', '/unattend:C:\Windows\Temp\generalize.xml'
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
            shutdown @('-s', '-t', '0', '-c', 'Shutdown;Bootstrapping failed on possible invalid deploymentID ', '-f', '-d', '4:5')
            exit
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
          return
        } elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          sleep 300
          return
          #shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        }
      } elseif  (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
        Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
        Write-Log -message  ('{0} :: Puppet apply successful. Waiting on Cloud-Image-Builder pickup' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
		return
      } else {
        Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $last_exit
        Start-sleep -s 300
        return
        #shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
Function set-restore_point {
  param (
    [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
    [string] $ronnin_key = "$mozilla_key\ronin_puppet",
    [string] $date = (Get-Date -Format "yyyy/mm/dd-HH:mm"),
    [int32] $max_boots
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    vssadmin delete shadows /all /quiet
    powershell.exe -Command Checkpoint-Computer -Description "default"

    if(!(Test-Path $ronnin_key)) {
      New-Item -Path HKLM:\SOFTWARE -Name Mozilla –Force
      New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet –Force
    }

    New-ItemProperty -Path "$ronnin_key" -name "restorable" -PropertyType  string -value yes
    New-ItemProperty -Path "$ronnin_key" -name "reboot_count" -PropertyType  Dword -value 0
    New-ItemProperty -Path "$ronnin_key" -name "last_restore_point" -PropertyType  string -value $date
    New-ItemProperty -Path "$ronnin_key" -name "restore_needed" -PropertyType  string -value false
    New-ItemProperty -Path "$ronnin_key" -name "max_boots" -PropertyType  Dword -value $max_boots
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
Function Start-Restore {
  param (
    [string] $ronin_key = "HKLM:\SOFTWARE\Mozilla\ronin_puppet",
    [int32] $boots = (Get-ItemProperty $ronin_key).reboot_count,
    [int32] $max_boots = (Get-ItemProperty $ronin_key).max_boots,
    [string] $restore_needed = (Get-ItemProperty $ronin_key).restore_needed,
    [string] $checkpoint_date = (Get-ItemProperty $ronin_key).last_restore_point

  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    if (($boots -ge $max_boots)  -or ($restore_needed -notlike "false")) {
        if ($boots -ge $max_boots){
            Write-Log -message  ('{0} :: System has reach the maxium number of reboots set at HKLM:\SOFTWARE\Mozilla\ronin_puppet\source\max_boots. Attempting restore.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
        if ($restore_needed -eq "gw_bad_config") {
            Write-Log -message  ('{0} :: Generic_worker has faild to start multiple times. Attempting restore.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
        if ($restore_needed -eq "puppetize_failed") {
            Write-Log -message  ('{0} :: Node has failed to Puppetize multiple times. Attempting restore .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
        else {
            Write-Log -message  ('{0} :: Restore attempted for unknown reason. Restore key equals {1} .' -f $($MyInvocation.MyCommand.Name), ($restore_needed )) -severity 'DEBUG'

        }
        Stop-ScheduledTask -TaskName maintain_system

        Write-Log -message  ('{0} :: Removing Generic-worker directory .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Stop-process -name generic-worker -force
        Remove-Item -Recurse -Force $env:systemdrive\generic-worker
        Remove-Item -Recurse -Force $env:systemdrive\mozilla-build
        Remove-Item -Recurse -Force $env:ALLUSERSPROFILE\puppetlabs\ronin
        Remove-Item –Path -Force $env:windir\temp\*
        sc delete "generic-worker"
        Remove-ItemProperty -path $ronin_key -recurse -force
        # OpenSSH will need to be addressed it fails after restore
        # For now commented out of the roles manifests
        # sc delete sshd
        # sc delete ssh-agent
        # Remove-Item -Recurse -Force $env:ALLUSERSPROFILE\ssh
        Write-Log -message  ('{0} :: Initiating system restore from {1}.' -f $($MyInvocation.MyCommand.Name), ($checkpoint_date)) -severity 'DEBUG'
        $RestoreNumber = (Get-ComputerRestorePoint | Where-Object {$_.Description -eq "default"})
        Restore-Computer -RestorePoint $RestoreNumber.SequenceNumber

    } else {
        Write-Log -message  ('{0} :: Restore is not needed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
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
Function Wait-On-MDT {
   param (
   )
   begin {
     Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
       while ((Test-Path "$env:systemdrive:\MININT")) {
         Write-Log -message  ('{0} ::Detecting MDT deployment has not completed. Waiting 10 seconds.'  -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
         Start-Sleep 10
       }
       Write-Log -message  ('{0} ::MDT deployment appears complete'  -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }
    end {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
