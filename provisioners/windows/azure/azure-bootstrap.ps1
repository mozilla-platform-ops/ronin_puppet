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
function Install-BootstrapModule {
  param (
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Revision,
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $filename = "bootstrap.psm1",
    [string] $module_name = ($filename).replace(".pms1",""),
    [string] $modulesPath = ('{0}\Modules\bootstrap' -f $pshome),
    [string] $bootstrap_module = "$modulesPath\bootstrap",
    [string] $moduleUrl = ('https://raw.githubusercontent.com/{0}/{1}/{2}/provisioners/windows/modules/{3}' -f $src_Organisation, $src_Repository, $src_Revision, $filename)
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    mkdir $bootstrap_module  -ErrorAction SilentlyContinue
    Invoke-WebRequest $moduleUrl -OutFile "$bootstrap_module\\$filename" -UseBasicParsing
    Get-Content -Encoding UTF8 "$bootstrap_module\\$filename" | Out-File -Encoding Unicode "$modulesPath\\$filename"
    Import-Module -Name $module_name
    }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Install-RemoveAppsModule {
  param (
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Revision,
    [string] $app_list  = "win10_default_apps.txt",
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $filename = "remove_default_apps.psm1",
    [string] $module_name = ($filename).replace(".pms1",""),
    [string] $modulesPath = ('{0}\Modules\remove_default_apps' -f $pshome),
    [string] $removeapps_module = "$modulesPath\remove_default_apps",
    [string] $moduleUrl = ('https://raw.githubusercontent.com/{0}/{1}/{2}/provisioners/windows/modules/{3}' -f $src_Organisation, $src_Repository, $src_Revision, $filename),
    [string] $listUrl = ('https://raw.githubusercontent.com/{0}/{1}/{2}/provisioners/windows/modules/{3}' -f $src_Organisation, $src_Repository, $src_Revision, $app_list)
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    mkdir $removeapps_module  -ErrorAction SilentlyContinue
    Invoke-WebRequest $moduleUrl -OutFile "$removeapps_module\\$filename" -UseBasicParsing
    Get-Content -Encoding UTF8 "$removeapps_module\\$filename" | Out-File -Encoding Unicode "$modulesPath\\$filename"
    Import-Module -Name $module_name

    Invoke-WebRequest $listUrl -OutFile "$local_dir\\$app_list" -UseBasicParsing
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Get-SysprepState {
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    try {
      $sysprepState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -Name 'ImageState').ImageState
      Write-Log -message ('{0} :: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State ImageState read as {1}' -f $($MyInvocation.MyCommand.Name), $sysprepState) -severity 'DEBUG'
    } catch {
      Write-Log -message ('{0} :: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State ImageState read failure. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
      $sysprepState = $null
    }
    return $sysprepState
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

# Ensuring scripts can run uninhibited
Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue

$workerType = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('workerType') })[0].value
$src_Organisation = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('sourceOrganisation') })[0].value
$src_Repository = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('sourceRepository') })[0].value
$src_Revision = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('sourceRevision') })[0].value
$image_provisioner = 'azure'
$audit_state_key = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State"
$hand_off_ready = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").hand_off_ready
$sysprepState = (Get-SysprepState)

#If ($hand_off_ready -eq 'yes') {
# start-sleep -s 60
# Bootstrap-CleanUp
# Write-Log -message  ('{0} :: Shutting down to hand off to Cloud-Image-Builder' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
# shutdown @('-p', '-f')
# exit
# }


switch -regex ($sysprepState) {
  'IMAGE_STATE_COMPLETE|IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT' {
    try {
      Set-ExecutionPolicy -ExecutionPolicy 'RemoteSigned' -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {
      Write-Log -message ('{0} :: failed to set powershell execution policy to remote signed. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'WARN'
	}

    If(test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet') {
      $stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
    }
    If(!(test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet')) {
      Set-ItemProperty -Path "$audit_state_key" -name ImageState -value IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT
      Setup-Logging
      Write-Log -message  ('{0} :: current Sysprep state {1}' -f $($MyInvocation.MyCommand.Name), $sysprepState) -severity 'DEBUG'
      Install-BootstrapModule -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision
      Set-RoninRegOptions  -workerType $workerType -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision -image_provisioner $image_provisioner
      Install-AzPrerequ
      Bootstrap-schtasks -workerType azure -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision -image_provisioner $image_provisioner
      Install-RemoveAppsModule -workerType azure -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision -image_provisioner $image_provisioner
	  $apps = @((Get-Content "$env:systemdrive\BootStrap\win10_default_apps.txt"))
      Remove_Apps -apps $apps
      shutdown @('-r', '-t', '0', '-c', 'Reboot; Prerequisites in place, logging setup, and registry setup', '-f', '-d', '4:5')

    }
    If (($stage -eq 'setup') -or ($stage -eq 'inprogress')){
      #$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
      #RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters ,1 ,True
      Set-ItemProperty -Path "$audit_state_key" -name ImageState -value IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT
      Install-BootstrapModule -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision
      Ronin-PreRun
      #do {
        #$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        #RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters ,1 ,True
        Bootstrap-AzPuppet
        #$stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
      #} until ($stage -like 'complete')
      #Write-Log -message  ('{0} :: Attempting to generalize image' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      #Generalize_Vm -sourceOrg $src_Organisation -sourceRepo $src_Repository -sourceRev $src_Revision -vm_type azure
      # Write-Log -message  ('{0} :: PAUSE TO RUN GEN COMMAND' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      #pause
    }
    If ($stage -eq 'complete') {
      Set-ItemProperty -Path "$audit_state_key" -name ImageState -value IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT
      Install-BootstrapModule -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision
      #do {
       # start-sleep -s 15
        #Write-Log -message  ('{0} :: Waiting on sysprep to complete. Sleep 15 seconds' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      #} until ($sysprepState -eq 'IMAGE_STATE_COMPLETE')
      Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name hand_off_ready -type  string -value yes
      Write-Log -message  ('{0} :: BOOTSTRAP COMPLETE {1}' -f $($MyInvocation.MyCommand.Name), $sysprepState) -severity 'DEBUG'
      Bootstrap-CleanUp
      Write-Log -message  ('{0} :: Attempting to generalize image' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      Generalize_Vm -sourceOrg $src_Organisation -sourceRepo $src_Repository -sourceRev $src_Revision -vm_type azure
      pause
      #Write-Log -message  ('{0} :: Shutting down to hand off to Cloud-Image-Builder' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      #shutdown @('-p', '-f')
    }
  }
  default {
    Write-Log -message ('{0} :: no available implementation for sysprep state: {1}' -f $($MyInvocation.MyCommand.Name), $sysprepState) -severity 'WARN'
    break
  }
}
