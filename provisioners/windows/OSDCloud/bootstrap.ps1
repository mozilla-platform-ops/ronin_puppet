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

Start-Sleep -Seconds 120

Write-host "Starting bootstrap using raw powershell scripts"

$worker_pool_id = 'win11-64-2009-hw-ref-alpha'
$role = "win11642009hwref"
$base_image = 'win11642009hwref'
$src_Organisation = 'jwmoss'
$src_Repository = 'ronin_puppet'
$src_Branch = 'win11'
$image_provisioner = 'OSDCloud'
#$workerID = Resolve-DnsName (Get-NetIPAddress | Where-Object {$PSItem.ipaddress -match "10."} ).IPAddress

$complete = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -ErrorAction "SilentlyContinue"

if ($complete -eq "complete") {
    Write-Log -message ('{0} :: Nothing to do!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    exit
}

Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

if (-Not (Test-Path "$env:systemdrive\BootStrap")) {
    Write-Log -message ('{0} :: Create C:\Bootstrap' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue 
}

## Check if logging exists through local directory and if it doesn't, set it up
if (-Not (Test-Path "$env:systemdrive\Program Files (x86)\nxlog")) {
    Write-Log -message  ('{0} :: Setting up logging' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog-ce-2.10.2150.msi" -outfile "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" -UseBasicParsing
    msiexec /i "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" /passive
    while (-Not (Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
    Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog.conf" -outfile "$env:systemdrive\Program Files (x86)\nxlog\conf\nxlog.conf" -UseBasicParsing
    while (-Not (Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
    Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/papertrail-bundle.pem" -outfile "$env:systemdrive\Program Files (x86)\nxlog\cert\papertrail-bundle.pem" -UseBasicParsing
    Restart-Service -Name nxlog -force
}

## Wait for nxlog to send logs
Start-Sleep -Seconds 15

## WinRM
$profile = Get-NetAdapter | Where-Object {$psitem.name -match "Ethernet"}
$network_category = Get-NetConnectionProfile -InterfaceAlias $profile.Name
if ($network_category.NetworkCategory -ne "Private") {
    Set-NetConnectionProfile -InterfaceAlias $profile.name -NetworkCategory "Private"
    Enable-PSRemoting -Force
}

<# ## WinRM
$winrm = Test-WSMan -ErrorAction "SilentlyContinue"
if ($null -eq $winrm) {
    Enable-PSRemoting -Force
}
 #>
<# if ($null -eq $workerID) {
    Rename-Computer -NewName "win11reftester01" -Force
}
else {
    Rename-Computer -NewName $workerID.NameHost -Force
}
 #>

## Check if modules are installed
## Install modules
Write-Log -message ('{0} :: Checking modules' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
@(
    "Carbon"
    "ugit",
    "kbupdate"
) | ForEach-Object {
    $hit = Get-Module -Name $PSItem
    if ($null -eq $hit) {
        Install-Module -Name $PSItem -AllowClobber -Force -Confirm:$false
    }
    Import-Module -Name $PSItem -Force -PassThru
}

## Setup logging and create c:\bootstrap
Write-Log -message ('{0} :: Setup logging and create c:\bootstrap on {1}' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME) -severity 'DEBUG'

## Check if C:\Bootstrap exists, and if it doesn't, create it
if (-Not (Test-Path "$env:systemdrive\BootStrap")) {
    Write-Log -message  ('{0} :: Create C:\Bootstrap' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue 
}

## Setup scheduled task if not setup already
if (-Not (Test-Path "$env:systemdrive\BootStrap\bootstrap.ps1")) {
    Write-Log -Message ('{0} :: Downloading bootstrap script to c:\bootstrap on {1}' -f $($MyInvocation.MyCommand.Name),$ENV:COMPUTERNAME) -severity 'DEBUG'
    Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
    $url = "https://raw.githubusercontent.com/jwmoss/ronin_puppet/win11/provisioners/windows/OSDCloud/bootstrap.ps1"
    $status = Invoke-WebRequest $url
    if ($status.StatusCode -ne 200) {
        Write-Log -Message ('{0} :: Unable to query raw github script. Status: {1}' -f $($MyInvocation.MyCommand.Name),$status.StatusCode) -severity 'DEBUG'
        exit 1
    }
    Invoke-WebRequest "https://raw.githubusercontent.com/jwmoss/ronin_puppet/win11/provisioners/windows/OSDCloud/bootstrap.ps1" -OutFile "$env:systemdrive\BootStrap\bootstrap-src.ps1" -UseBasicParsing
    Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\bootstrap.ps1
    Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f
    $check = Get-Content "$env:systemdrive\BootStrap\bootstrap.ps1"
    if ($null -ne $check) {
        Write-Log -Message ('{0} :: Setup bootstrap scheduled task on {1}' -f $($MyInvocation.MyCommand.Name),$ENV:COMPUTERNAME) -severity 'DEBUG'
    }
    else {
        Write-Log -Message ('{0} :: Unable to clone bootstrap scheduled task on {1}' -f $($MyInvocation.MyCommand.Name),$ENV:COMPUTERNAME) -severity 'DEBUG'
    }
}

$updates_check = Get-ChildItem -Path "C:\" -Filter *windows11*

if ($null -eq $updates_check) {
    Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/BootStrap/windows11.0-kb5022497-x64-ndp481_92ce32e8d1d29d5b572e929f4ff90e85a012b4d6.msu" -OutFile "$env:systemdrive\kb5022497.msu"
    #Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/BootStrap/windows11.0-kb5023360-x64_c468c54177d262cb0c1927283d807b8f9afe3046.cab" -OutFile "$env:systemdrive\kb5023360.cab"
    Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/BootStrap/windows11.0-kb5023527-x64_076cd9782ebb8aed56ad5d99c07201035d92e66a.cab" -OutFile "$env:systemdrive\kb5023527.cab"
    Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/BootStrap/windows11.0-kb5026372-x64_d2e542ce70571b093d815adb9013ed467a3e0a85.msu" -OutFile "$env:systemdrive\kb5026372.msu"

    Get-ChildItem -Path "C:\" -Filter *kb* | ForEach-Object {
        Write-Log -message ('{0} :: Installing {1} on {2}' -f $($MyInvocation.MyCommand.Name), $PSItem.name, $ENV:COMPUTERNAME) -severity 'DEBUG'
        Install-KbUpdate -ComputerName "localhost" -FilePath $PSItem.fullname
    } 

}

## Grant SeServiceLogonRight and reboot
$logonrights = Get-CPrivilege -Identity "Administrator"
if ($logonrights -ne "SeServiceLogonRight") {
    Write-Log -message ('{0} :: Setting SeServiceLogonRight for Administrator' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Grant-CPrivilege -Identity "Administrator" -Privilege SeServiceLogonRight
    Restart-Computer -Confirm:$false -Force
}

$winVer = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

## output Windows build
Write-Log -message ('{0} :: Windows Version {1}.{2}.{3}' -f $($MyInvocation.MyCommand.Name), $winVer.ReleaseID,$winVer.CurrentBuildNumber,$winVer.UBR ) -severity 'DEBUG'

## Install git, puppet, nodes.pp
Write-Log -message ('{0} :: Setting power settings with powercfg' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
powercfg.exe -x -standby-timeout-ac 0
powercfg.exe -x -monitor-timeout-ac 0

## Puppet
If (-Not (Test-Path "$env:systemdrive\puppet-agent-6.28.0-x64.msi")) {
    Write-Log -Message ('{0} :: Downloading Puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/puppet-agent-6.28.0-x64.msi" -UseBasicParsing -OutFile "$env:systemdrive\puppet-agent-6.28.0-x64.msi"
}

## Git
If (-Not (Test-Path "$env:systemdrive\Git-2.37.3-64-bit.exe")) {
    Write-Log -Message ('{0} :: Downloading Git' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/Git-2.37.3-64-bit.exe" -UseBasicParsing -OutFile "$env:systemdrive\Git-2.37.3-64-bit.exe"
}

If (-Not (Test-Path "$env:systemdrive\bootstrap\nodes.pp")) {
    Write-Log -Message ('{0} :: Downloading Nodes.pp' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nodes.pp" -UseBasicParsing -OutFile "$env:systemdrive\bootstrap\nodes.pp"
}

## Install Git
if (-Not (Test-Path "$env:programfiles\git\bin\git.exe")) {
    Write-Log -Message ('{0} :: Installing git.exe' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Start-Process -FilePath "$env:systemdrive\Git-2.37.3-64-bit.exe" -ArgumentList @(
        "/verysilent"
    ) -Wait -NoNewWindow
}

#New-Item -Path "$env:systemdrive\" -Name "prework" -ItemType File
if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
    ## Install Puppet using ServiceUI.exe to install as SYSTEM
    Write-Log -Message ('{0} :: Installing puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Start-Process msiexec -ArgumentList @("/qn", "/norestart", "/i", "$env:systemdrive\puppet-agent-6.28.0-x64.msi") -Wait
    Write-Log -message  ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), "puppet-agent-6.28.0-x64.msi") -severity 'DEBUG'
    Write-Host ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), "puppet-agent-6.28.0-x64.msi")
    if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
        Write-Host "Did not install puppet"
        exit 1
    }
    $env:PATH += ";C:\Program Files\Puppet Labs\Puppet\bin"
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

## Set registry options
If (-Not ( test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet")) {
    Write-Log -Message ('{0} :: Creating HKLM:\SOFTWARE\Mozilla\ronin_puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    New-Item -Path HKLM:\SOFTWARE -Name Mozilla -force
    New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet -force
}

Write-Log -Message ('{0} :: Setting HKLM:\SOFTWARE\Mozilla\ronin_puppet values' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
New-Item -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name source -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'image_provisioner' -Value $image_provisioner -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'worker_pool_id' -Value $worker_pool_id -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'role' -Value $base_image -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'inmutable' -Value 'false' -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'last_run_exit' -Value '0' -PropertyType Dword -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'setup' -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Organisation' -Value $src_Organisation -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Repository' -Value $src_Repository -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Branch' -Value $src_Branch -PropertyType String -force

## Contents 
if (-Not (Test-Path "$env:systemdrive\ronin\LICENSE")) {
    Write-Log -Message ('{0} :: Cloning {1}' -f $($MyInvocation.MyCommand.Name)), "$src_Organisation/$src_Repository" -severity 'DEBUG'
    git config --global --add safe.directory "C:/ronin"
    git clone "https://github.com/$($src_Organisation)/$($src_Repository)" "$env:systemdrive\ronin"
}

Set-Location "$env:systemdrive\ronin"

## ugit convert git output to pscustomobject
$branch = git branch | Where-object { $PSItem.isCurrentBranch -eq $true }

if ($branch -ne $src_branch) {
    git checkout $src_branch
    git pull
    git config --global --add safe.directory "C:/ronin"
}

## Set nodes.pp to point to win11642009hwref.yaml file with ronin puppet
if (-not (Test-path "$env:systemdrive\ronin\manifests\nodes.pp")) {
    Copy-item -Path "$env:systemdrive\BootStrap\nodes.pp" -Destination "$env:systemdrive\ronin\manifests\nodes.pp" -force
    (Get-Content -path "$env:systemdrive\ronin\manifests\nodes.pp") -replace 'roles::role', "roles::$role" | Set-Content "$env:systemdrive\ronin\manifests\nodes.pp"    
}
## Copy the secrets from the image (from osdcloud) to ronin data secrets
if (-Not (Test-path "$env:systemdrive\ronin\data\secrets")) {
    New-Item -Path "$env:systemdrive\ronin\data" -Name "secrets" -ItemType Directory -Force
    Copy-item -path "$env:systemdrive\programdata\secrets\*" -destination "$env:systemdrive\ronin\data\secrets" -recurse -force
}

## Set directory for logs
Set-Location $env:systemdrive\ronin
If (-Not (test-path $env:systemdrive\logs\old)) {
    New-Item -ItemType Directory -Force -Path $env:systemdrive\logs\old
}

## Run puppet
Set-Location $env:systemdrive\ronin
Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'inprogress'
$env:path = "$env:programfiles\Puppet Labs\Puppet\bin;$env:path"
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

#Get-ChildItem -Path $env:systemdrive\logs\*.log -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue
Get-ChildItem -Path $env:systemdrive\logs\*.json -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue

$logDate = $(get-date -format yyyyMMdd-HHmm)

Write-Log -Message ('{0} :: Running Puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $env:systemdrive\logs\$($logdate)-bootstrap-puppet.json
[int]$puppet_exit = $LastExitCode
Write-Log -Message ('{0} :: Puppet error code {1}' -f $($MyInvocation.MyCommand.Name)), $puppet_exit -severity 'DEBUG'
switch ($puppet_exit) {
    0 {
        Write-Log -message  ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'complete'
        Restart-Computer -Confirm:$false -Force
    }
    1 {
        Write-Log -message ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path $ronnin_key -name "last_run_exit" -value $puppet_exit
        Add-Content "$logdir\$logdate-bootstrap-puppet.json" "`n]" | ConvertFrom-Json | Where-Object {
            $psitem.Level -match "warning|err" 
        } | ForEach-Object {
            $data = $psitem
            Write-Log -message ('{0} :: Puppet warning or error log {1}' -f $($MyInvocation.MyCommand.Name), $data) -severity 'DEBUG'
        }
        exit 1
    }
    2 {
        Write-Log -message ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'complete'
        Restart-Computer -Confirm:$false -Force
    }
    4 {
        Write-Log -message ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
        ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
        Add-Content "$logdir\$logdate-bootstrap-puppet.json" "`n]" | ConvertFrom-Json | Where-Object {
            $psitem.Level -match "warning|err" 
        } | ForEach-Object {
            $data = $psitem
            Write-Log -message ('{0} :: Puppet json output: {1}' -f $($MyInvocation.MyCommand.Name), $data) -severity 'DEBUG'
        }
        exit 4
    }
    6 {
        Write-Log -message ('{0} :: Puppet apply succeeded, but included changes and failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded, but included changes and failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
        ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
        Add-Content "$logdir\$logdate-bootstrap-puppet.json" "`n]" | ConvertFrom-Json | Where-Object {
            $psitem.Level -match "warning|err" 
        } | ForEach-Object {
            $data = $psitem
            Write-Log -message ('{0} :: Puppet json output: {1}' -f $($MyInvocation.MyCommand.Name), $data) -severity 'DEBUG'
        }
        exit 6
    }
    Default {
        Write-Log -message  ('{0} :: Unable to determine state post Puppet apply :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $last_exit
        exit 1
    }
}
New-Item -Path "$env:systemdrive" -Name "Complete" -ItemType File
Remove-Item "$env:systemdrive\prework" -Confirm:$false -Force