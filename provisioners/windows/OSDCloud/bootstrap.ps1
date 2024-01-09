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

$worker_pool_id = 'win11-64-2009-hw-ref'
$role = "win11642009hwref"
$base_image = 'win11642009hwref'
$src_Organisation = 'mozilla-platform-ops'
$src_Repository = 'ronin_puppet'
$src_Branch = 'win11ref'
$image_provisioner = 'OSDCloud'

$complete = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -ErrorAction "SilentlyContinue"

if ($complete -eq "complete") {
    Write-Log -message ('{0} :: Nothing to do!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    if (Test-Path "C:\azcredentials.yaml") {
        Remove-Item -Path "C:\azcredentials.yaml" -Confirm:$false -Force
    }
    exit
}

Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

if (-Not (Test-Path "$env:systemdrive\BootStrap")) {
    Write-Log -message ('{0} :: Create C:\Bootstrap' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue 
}

Write-Log -message ('{0} :: Checking modules' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
@(
    "Carbon"
    "ugit",
    #"kbupdate",
    "Powershell-Yaml"
) | ForEach-Object {
    $hit = Get-Module -Name $PSItem
    if ($null -eq $hit) {
        Install-Module -Name $PSItem -AllowClobber -Force -Confirm:$false
    }
    Import-Module -Name $PSItem -Force -PassThru
}

## Download azcopy locally
## https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10#use-in-a-script
if (-Not (Test-Path "$ENV:systemdrive\azcopy.exe")) {
    Write-Log -message  ('{0} :: Installing azcopy' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $LatestAzCopy = (Invoke-WebRequest -Uri https://aka.ms/downloadazcopy-v10-windows -MaximumRedirection 0 -ErrorAction SilentlyContinue).headers.location
    Invoke-WebRequest $LatestAzCopy -OutFile "$env:systemdrive\azcopy.zip"
    Write-host "Downloaded azcopy to $ENV:systemdrive\azcopy.zip"
    Expand-Archive -Path "$ENV:systemdrive\azcopy.zip" -DestinationPath "$ENV:systemdrive\azcopy"
    $azcopy_path = Get-ChildItem "$ENV:systemdrive\azcopy" -Recurse | Where-Object { $PSItem.name -eq "azcopy.exe" }
    Copy-Item $azcopy_path.FullName -Destination "$ENV:systemdrive\"
    Remove-Item "$ENV:systemdrive\azcopy.zip"
}

## Check if logging exists through local directory and if it doesn't, set it up
if (-Not (Test-Path "$env:systemdrive\Program Files (x86)\nxlog")) {
    Write-Log -message  ('{0} :: Setting up logging' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $creds = ConvertFrom-Yaml -Yaml (Get-Content -Path "C:\azcredentials.yaml" -Raw)
    $ENV:AZCOPY_SPA_APPLICATION_ID = $creds.azcopy_app_id
    $ENV:AZCOPY_SPA_CLIENT_SECRET = $creds.azcopy_app_client_secret
    $ENV:AZCOPY_TENANT_ID = $creds.azcopy_tenant_id
    
    $nxlog_azcopy = @(
        "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog-ce-2.10.2150.msi",
        "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi"
    )

    & "$ENV:systemdrive\azcopy.exe" copy $nxlog_azcopy 

    if (-Not (Test-Path "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi")) {
        Write-Log -Message ('{0} :: nxlog failed to download' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }

    msiexec /i "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" /passive
    while (-Not (Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }

    $nxlogconf_azcopy = @(
        "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog.conf",
        "$env:systemdrive\Program Files (x86)\nxlog\conf\nxlog.conf"
    )

    & "$ENV:systemdrive\azcopy.exe" copy $nxlogconf_azcopy

    while (-Not (Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
    
    $papertrail_azcopy = @(
        "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/papertrail-bundle.pem",
        "$env:systemdrive\Program Files (x86)\nxlog\cert\papertrail-bundle.pem"
    )

    & "$ENV:systemdrive\azcopy.exe" copy $papertrail_azcopy

    Restart-Service -Name nxlog -force
}

## Wait for nxlog to send logs
Start-Sleep -Seconds 15

## WinRM
$adapter = Get-NetAdapter | Where-Object { $psitem.name -match "Ethernet" }
$network_category = Get-NetConnectionProfile -InterfaceAlias $adapter.Name
if ($network_category.NetworkCategory -ne "Private") {
    Set-NetConnectionProfile -InterfaceAlias $adapter.name -NetworkCategory "Private"
    Enable-PSRemoting -Force
}

## Check if C:\Bootstrap exists, and if it doesn't, create it
if (-Not (Test-Path "$env:systemdrive\BootStrap")) {
    ## Setup logging and create c:\bootstrap
    Write-Log -message  ('{0} :: Create C:\Bootstrap' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue 
}

## Setup scheduled task if not setup already
if (-Not (Test-Path "$env:systemdrive\BootStrap\bootstrap.ps1")) {
    Write-Log -Message ('{0} :: Downloading bootstrap script to c:\bootstrap on {1}' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME) -severity 'DEBUG'
    Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
    $url = ("https://raw.githubusercontent.com/{0}/{1}/{2}/provisioners/windows/{3}/bootstrap.ps1" -f $src_Organisation,$src_Repository,$src_Branch,$image_provisioner)
    $status = Invoke-WebRequest $url
    if ($status.StatusCode -ne 200) {
        Write-Log -Message ('{0} :: Unable to query raw github script. Status: {1}' -f $($MyInvocation.MyCommand.Name), $status.StatusCode) -severity 'DEBUG'
        exit 1
    }
    Invoke-WebRequest $url -OutFile "$env:systemdrive\BootStrap\bootstrap-src.ps1" -UseBasicParsing
    Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\bootstrap.ps1
    Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f
    $check = Get-Content "$env:systemdrive\BootStrap\bootstrap.ps1"
    if ($null -ne $check) {
        Write-Log -Message ('{0} :: Setup bootstrap scheduled task on {1}' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME) -severity 'DEBUG'
    }
    else {
        Write-Log -Message ('{0} :: Unable to clone bootstrap scheduled task on {1}' -f $($MyInvocation.MyCommand.Name), $ENV:COMPUTERNAME) -severity 'DEBUG'
    }
}

<# ## Check for windows update and install the latest
$updates_check = Get-KbNeededUpdate -UseWindowsUpdate | Where-Object {
    $PSItem.Title -notmatch "Preview"
}

if ($null -ne $updates_check) {
    Write-Log -message ('{0} :: Installing {1} on {2}' -f $($MyInvocation.MyCommand.Name), $PSItem.name, $ENV:COMPUTERNAME) -severity 'DEBUG'
    $updates_check | Install-KbUpdate -Method "WindowsUpdate"
} #>

## Grant SeServiceLogonRight and reboot
$logonrights = Get-CPrivilege -Identity "Administrator"
if ($logonrights -ne "SeServiceLogonRight") {
    Write-Log -message ('{0} :: Setting SeServiceLogonRight for Administrator' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Grant-CPrivilege -Identity "Administrator" -Privilege SeServiceLogonRight
    Restart-Computer -Confirm:$false -Force
}

$winVer = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

## output Windows build
Write-Log -message ('{0} :: Windows Version {1}.{2}.{3}' -f $($MyInvocation.MyCommand.Name), $winVer.ReleaseID, $winVer.CurrentBuildNumber, $winVer.UBR ) -severity 'DEBUG'

## Install git, puppet, nodes.pp
Write-Log -message ('{0} :: Setting power settings with powercfg' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
powercfg.exe -x -standby-timeout-ac 0
powercfg.exe -x -monitor-timeout-ac 0

## Puppet
If (-Not (Test-Path "$env:systemdrive\puppet-agent-6.28.0-x64.msi")) {
    Write-Log -Message ('{0} :: Downloading Puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    
    $creds = ConvertFrom-Yaml -Yaml (Get-Content -Path "C:\azcredentials.yaml" -Raw)
    $ENV:AZCOPY_SPA_APPLICATION_ID = $creds.azcopy_app_id
    $ENV:AZCOPY_SPA_CLIENT_SECRET = $creds.azcopy_app_client_secret
    $ENV:AZCOPY_TENANT_ID = $creds.azcopy_tenant_id
    
    Start-Process -FilePath "$ENV:systemdrive\azcopy.exe" -ArgumentList @(
        "copy",
        "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/puppet-agent-6.28.0-x64.msi",
        "$env:systemdrive\puppet-agent-6.28.0-x64.msi"
    ) -Wait -NoNewWindow

    if (-Not (Test-Path "$env:systemdrive\puppet-agent-6.28.0-x64.msi")) {
        Write-Log -Message ('{0} :: Puppet failed to download' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }
}

## Git
If (-Not (Test-Path "$env:systemdrive\Git-2.37.3-64-bit.exe")) {
    Write-Log -Message ('{0} :: Downloading Git' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    
    $creds = ConvertFrom-Yaml -Yaml (Get-Content -Path "C:\azcredentials.yaml" -Raw)
    $ENV:AZCOPY_SPA_APPLICATION_ID = $creds.azcopy_app_id
    $ENV:AZCOPY_SPA_CLIENT_SECRET = $creds.azcopy_app_client_secret
    $ENV:AZCOPY_TENANT_ID = $creds.azcopy_tenant_id
    
    Start-Process -FilePath "$ENV:systemdrive\azcopy.exe" -ArgumentList @(
        "copy",
        "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/Git-2.37.3-64-bit.exe",
        "$env:systemdrive\Git-2.37.3-64-bit.exe"
    ) -Wait -NoNewWindow

}

If (-Not (Test-Path "$env:systemdrive\bootstrap\nodes.pp")) {
    Write-Log -Message ('{0} :: Downloading Nodes.pp' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $creds = ConvertFrom-Yaml -Yaml (Get-Content -Path "C:\azcredentials.yaml" -Raw)
    $ENV:AZCOPY_SPA_APPLICATION_ID = $creds.azcopy_app_id
    $ENV:AZCOPY_SPA_CLIENT_SECRET = $creds.azcopy_app_client_secret
    $ENV:AZCOPY_TENANT_ID = $creds.azcopy_tenant_id
    
    Start-Process -FilePath "$ENV:systemdrive\azcopy.exe" -ArgumentList @(
        "copy",
        "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nodes.pp",
        "$env:systemdrive\bootstrap\nodes.pp"
    ) -Wait -NoNewWindow

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

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User") 

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
Write-Log -Message ('{0} :: Puppet error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'

if (Test-Path "C:\azcredentials.yaml") {
    Remove-Item -Path "C:\azcredentials.yaml" -Confirm:$false -Force
}

switch ($puppet_exit) {
    0 {
        Write-Log -message  ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'complete'
        ## Cleanup
        @(
            "LAN-Win11-1.1.3.34.zip",
            "puppet-agent-6.28.0-x64.msi",
            "Git-2.37.3-64-bit.exe",
            "azcopy.exe"
        ) | ForEach-Object {
            Remove-Item -Path "$ENV:SystemDrive\$PSItem" -Confirm:$false -Force
        }
        slmgr.vbs -skms "KMS02.ad.mozilla.com:1688"
        slmgr.vbs -ato
        Restart-Computer -Confirm:$false -Force
    }
    1 {
        Write-Log -message ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path $ronnin_key -name "last_run_exit" -value $puppet_exit
        ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
        Add-Content "$logdir\$logdate-bootstrap-puppet.json" "`n]" 
        $log = Get-Content "$logdir\$logdate-bootstrap-puppet.json" | ConvertFrom-Json 
        $log | Where-Object {
            $psitem.Level -match "warning|err" -and $_.message -notmatch "Client Certificate|Private Key"
        } | ForEach-Object {
            $data = $psitem
            Write-Log -message ('{0} :: Puppet File {1}' -f $($MyInvocation.MyCommand.Name), $data.file) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Message {1}' -f $($MyInvocation.MyCommand.Name), $data.message) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Level {1}' -f $($MyInvocation.MyCommand.Name), $data.level) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Line {1}' -f $($MyInvocation.MyCommand.Name), $data.line) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Source {1}' -f $($MyInvocation.MyCommand.Name), $data.source) -severity 'DEBUG'
        }
        exit 1
    }
    2 {
        Write-Log -message ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -name last_run_exit -value $puppet_exit
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'complete'
        ## Cleanup
        @(
            "LAN-Win11-1.1.3.34.zip",
            "puppet-agent-6.28.0-x64.msi",
            "Git-2.37.3-64-bit.exe",
            "azcopy.exe"
        ) | ForEach-Object {
            Remove-Item -Path "$ENV:SystemDrive\$PSItem" -Confirm:$false -Force
        }
        slmgr.vbs -skms "KMS02.ad.mozilla.com:1688"
        slmgr.vbs -ato
        Restart-Computer -Confirm:$false -Force
    }
    4 {
        Write-Log -message ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
        ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
        Add-Content "$logdir\$logdate-bootstrap-puppet.json" "`n]" 
        $log = Get-Content "$logdir\$logdate-bootstrap-puppet.json" | ConvertFrom-Json 
        $log | Where-Object {
            $psitem.Level -match "warning|err" -and $_.message -notmatch "Client Certificate|Private Key"
        } | ForEach-Object {
            $data = $psitem
            Write-Log -message ('{0} :: Puppet File {1}' -f $($MyInvocation.MyCommand.Name), $data.file) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Message {1}' -f $($MyInvocation.MyCommand.Name), $data.message) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Level {1}' -f $($MyInvocation.MyCommand.Name), $data.level) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Line {1}' -f $($MyInvocation.MyCommand.Name), $data.line) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Source {1}' -f $($MyInvocation.MyCommand.Name), $data.source) -severity 'DEBUG'
        }
        exit 4
    }
    6 {
        Write-Log -message ('{0} :: Puppet apply succeeded, but included changes and failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet apply succeeded, but included changes and failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
        Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
        ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
        Add-Content "$logdir\$logdate-bootstrap-puppet.json" "`n]" 
        $log = Get-Content "$logdir\$logdate-bootstrap-puppet.json" | ConvertFrom-Json 
        $log | Where-Object {
            $psitem.Level -match "warning|err" -and $_.message -notmatch "Client Certificate|Private Key"
        } | ForEach-Object {
            $data = $psitem
            Write-Log -message ('{0} :: Puppet File {1}' -f $($MyInvocation.MyCommand.Name), $data.file) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Message {1}' -f $($MyInvocation.MyCommand.Name), $data.message) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Level {1}' -f $($MyInvocation.MyCommand.Name), $data.level) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Line {1}' -f $($MyInvocation.MyCommand.Name), $data.line) -severity 'DEBUG'
            Write-Log -message ('{0} :: Puppet Source {1}' -f $($MyInvocation.MyCommand.Name), $data.source) -severity 'DEBUG'
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