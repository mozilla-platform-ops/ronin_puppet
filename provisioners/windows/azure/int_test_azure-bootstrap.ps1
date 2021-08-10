<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function InstallRoninModule {
  param (
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Revision,
    [string] $moduleName,
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $filename = ('{0}.psm1' -f $moduleName),
    [string] $module_name = ($moduleName).replace(".pms1",""),
    [string] $modulesPath = ('{0}\Modules\{1}' -f $pshome, $moduleName),
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
    Import-Module -Name $moduleName
    }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}

# Ensuring scripts can run uninhibited
# This is noisey but works
Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue

$workerType = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('workerType') })[0].value
$test_location = ((((Invoke-WebRequest -Headers @{'Metadata'=$true} -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList| ? { $_.name -eq ('test_location') })[0].value

$mozilla_key = "HKLM:\SOFTWARE\Mozilla\"
$ronnin_key = "$mozilla_key\ronin_puppet"

If(!( test-path "$ronnin_key")) {
    New-Item -Path HKLM:\SOFTWARE -Name Mozilla –Force
    New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet –Force
}

New-ItemProperty -Path "$ronnin_key" -Name 'workerType' -Value "$workerType" -PropertyType String
New-ItemProperty -Path "$ronnin_key" -Name '$test_location' -Value "$test_location" -PropertyType String
# We look for bootstrap_stage for logging configuration in roles_profiles/manifests/profiles/logging.pp
New-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete' -PropertyType String

# Using the azure module to ensure the same software is used in testing and production
InstallRoninModule -moduleName azure-bootstrap -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision
AzInstall-Prerequ
AzMount-DiskTwo
AzSet-DriveLetters
