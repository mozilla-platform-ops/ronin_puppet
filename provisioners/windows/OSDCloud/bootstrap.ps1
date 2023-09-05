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

Write-host "Starting bootstrap using raw powershell scripts"

$worker_pool_id = 'win11-64-2009-hw-ref-alpha'
$role = "win11642009hwref"
$base_image = 'win11642009hwref'
$src_Organisation = 'jwmoss'
$src_Repository = 'ronin_puppet'
$src_Branch = 'win11'
$image_provisioner = 'OSDCloud'

Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

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

$complete = Test-Path -Path "$env:systemdrive\complete"
$prework = Test-Path "$env:systemdrive\prework"

if ($complete) {
    Write-Log -message  ('{0} :: Nothing to do!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    exit 0
}

if (-Not $prework) {
    ## Install modules
    Write-Log -message  ('{0} :: Installing modules' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    @(
        "Carbon",
        "PSWindowsUpdate",
        "ugit"
    ) | ForEach-Object {
        Install-Module -Name $PSItem -AllowClobber -Force -Confirm:$false
        Import-Module -Name $PSItem -Force -PassThru
    }

    ## Grant SeServiceLogonRight and reboot
    if (Get-CPrivilege -Identity "Administrator" -ne "SeServiceLogonRight") {
        Write-Log -message ('{0} :: Setting SeServiceLogonRight for Administrator' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Grant-CPrivilege -Identity "Administrator" -Privilege SeServiceLogonRight
    }

    ## Setup logging and create c:\bootstrap
    Write-host "Setup logging and create c:\bootstrap on $ENV:COMPUTERNAME"

    ## Check if C:\Bootstrap exists, and if it doesn't, create it
    if (-Not (Test-Path "$env:systemdrive\BootStrap")) {
        Write-Log -message  ('{0} :: Create C:\Bootstrap' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        $null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue 
    }

    ## Setup scheduled task if not setup already
    if (-Not (Test-Path "$env:systemdrive\BootStrap\bootstrap.ps1")) {
        Write-Log -Message ('{0} :: Downloading bootstrap script to c:\bootstrap on $ENV:COMPUTERNAME' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
        Invoke-WebRequest "https://raw.githubusercontent.com/jwmoss/ronin_puppet/win11/provisioners/windows/OSDCloud/bootstrap_test.ps1" -OutFile "$env:systemdrive\BootStrap\bootstrap-src.ps1" -UseBasicParsing
        Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\bootstrap.ps1
        Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f
    }

    ## Install git, puppet, nodes.pp
    powercfg.exe -x -standby-timeout-ac 0
    powercfg.exe -x -monitor-timeout-ac 0

    ## Download the bootstrap_azure_**.zip file to C:\scratch
    ## Download git, puppet, and nodes.pp

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
        Write-host "Installing git.exe"
        Start-Process -FilePath "$env:systemdrive\Git-2.37.3-64-bit.exe" -ArgumentList @(
            "/verysilent"
        ) -Wait -NoNewWindow    
    }

    New-Item -Path "$env:systemdrive" -Name "prework" -ItemType File

    Restart-Computer -Confirm:$false -Force
}
else {
    Import-Module ugit -Force -PassThru
    Import-Module Carbon -Force -PassThru
    Import-Module PSWindowsUpdate -Force -PassThru

    if (-Not ("C:\Program Files\Puppet Labs\Puppet\bin")) {
        ## Install Puppet using ServiceUI.exe to install as SYSTEM
        Write-Log -Message ('{0} :: Installing puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Start-Process msiexec -ArgumentList @("/qn", "/norestart", "/i", "$env:systemdrive\$puppet") -Wait
        Write-Log -message  ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet)
        if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
            Write-Host "Did not install puppet"
            exit 1
        }
        $env:PATH += ";C:\Program Files\Puppet Labs\Puppet\bin"
    }

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
        git clone "https://github.com/$src_Organisation/$src_Repository" "$env:systemdrive\ronin"
    }

    Set-Location "$env:systemdrive\ronin"

    ## ugit convert git output to pscustomobject
    $branch = git branch | Where-object { $PSItem.isCurrentBranch -eq $true }

    if ($branch -ne $src_branch) {
        git checkout $src_branch
        git pull
    }

    git pull

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

    Get-ChildItem -Path $env:systemdrive\logs\*.log -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:systemdrive\logs\*.json -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue

    puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $env:systemdrive\logs\$(get-date -format yyyyMMdd-HHmm)-bootstrap-puppet.log, $env:systemdrive\logs\$(get-date -format yyyyMMdd-HHmm)-bootstrap-puppet.json
    [int]$puppet_exit = $LastExitCode
    Write-Log -Message ('{0} :: Puppet error code {1}' -f $($MyInvocation.MyCommand.Name)), $puppet_exit -severity 'DEBUG'
    switch ($puppet_exit) {
        0 {
            Write-Log -message  ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
            Write-Host ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
            Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
            Set-ItemProperty -Path $ronnin_key -Name 'bootstrap_stage' -Value 'complete'
        }
        1 {
            Write-Log -message ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
            Write-Host ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
            Set-ItemProperty -Path $ronnin_key -name "last_run_exit" -value $puppet_exit
            Add-Content "$logdir\$datetime-bootstrap-puppet.json" "`n]" | ConvertFrom-Json | Where-Object {
                $psitem.Level -match "warning|err" 
            } | ForEach-Object {
                Write-Output $psitem
            }
            exit 1
        }
        2 {
            Write-Log -message ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
            Write-Host ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
            Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
            Set-ItemProperty -Path $ronnin_key -Name 'bootstrap_stage' -Value 'complete'
            exit 2
        }
        4 {
            Write-Log -message ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
            Write-Host ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
            Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
            ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
            Add-Content "$logdir\$datetime-bootstrap-puppet.json" "`n]" | ConvertFrom-Json | Where-Object {
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
            Add-Content "$logdir\$datetime-bootstrap-puppet.json" "`n]" | ConvertFrom-Json | Where-Object {
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
}
