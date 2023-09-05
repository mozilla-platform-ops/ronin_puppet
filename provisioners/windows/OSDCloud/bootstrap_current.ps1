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

function Set-Logging {
    param (
        [string] $ext_src = "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites",
        [string] $local_dir = "$env:systemdrive\BootStrap",
        [string] $nxlog_msi = "nxlog-ce-2.10.2150.msi",
        [string] $nxlog_conf = "nxlog.conf",
        [string] $nxlog_pem  = "papertrail-bundle.pem",
        [string] $nxlog_dir   = "$env:systemdrive\Program Files (x86)\nxlog"
    )
    begin {
        Write-Host ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime())
    }
    process {
        $null = New-Item -ItemType Directory -Force -Path $local_dir -ErrorAction SilentlyContinue
        Invoke-WebRequest $ext_src/$nxlog_msi -outfile $local_dir\$nxlog_msi -UseBasicParsing
        msiexec /i $local_dir\$nxlog_msi /passive
        while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
        Invoke-WebRequest  $ext_src/$nxlog_conf -outfile "$nxlog_dir\conf\$nxlog_conf" -UseBasicParsing
        while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
        Invoke-WebRequest  $ext_src/$nxlog_pem -outfile "$nxlog_dir\cert\$nxlog_pem" -UseBasicParsing
        Restart-Service -Name nxlog -force
    }
    end {
        Write-Host ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime())
    }
}

function Set-RoninRegOptions {
    param (
        [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
        [string] $ronnin_key = "$mozilla_key\ronin_puppet",
        [string] $source_key = "$ronnin_key\source",
        [string] $image_provisioner,
        [string] $worker_pool_id,
        [string] $base_image,
        [string] $src_Organisation,
        [string] $src_Repository,
        [string] $src_Branch
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        If (!( test-path "$ronnin_key")) {
            New-Item -Path HKLM:\SOFTWARE -Name Mozilla -force
            New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet -force
        }

        New-Item -Path $ronnin_key -Name source -force
        New-ItemProperty -Path "$ronnin_key" -Name 'image_provisioner' -Value "$image_provisioner" -PropertyType String  -force
        New-ItemProperty -Path "$ronnin_key" -Name 'worker_pool_id' -Value "$worker_pool_id" -PropertyType String -force
        New-ItemProperty -Path "$ronnin_key" -Name 'role' -Value "$base_image" -PropertyType String -force
        Write-Log -message  ('{0} :: Node workerType set to {1}' -f $($MyInvocation.MyCommand.Name), ($worker_pool_id)) -severity 'DEBUG'

        New-ItemProperty -Path "$ronnin_key" -Name 'inmutable' -Value 'false' -PropertyType String -force
        New-ItemProperty -Path "$ronnin_key" -Name 'last_run_exit' -Value '0' -PropertyType Dword -force
        New-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'setup' -PropertyType String -force

        New-ItemProperty -Path "$source_key" -Name 'Organisation' -Value "$src_Organisation" -PropertyType String -force
        New-ItemProperty -Path "$source_key" -Name 'Repository' -Value "$src_Repository" -PropertyType String -force
        New-ItemProperty -Path "$source_key" -Name 'Branch' -Value "$src_Branch" -PropertyType String -force
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Install-DCPrerequ {
    param (
        [string] $ext_src = "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites",
        [string] $local_dir = "$env:systemdrive\BootStrap",
        [string] $work_dir = "$env:systemdrive\scratch",
        [string] $git = "Git-2.37.3-64-bit.exe",
        [string] $puppet = "puppet-agent-6.28.0-x64.msi",
        [string] $vault_file = "azure_vault_template.yaml",
        [string] $bootzip = "BootStrap_Azure_07-2022.zip",
        [string] $manifest = "nodes.pp"
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        Write-Host ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime())
    }
    process {

        powercfg.exe -x -standby-timeout-ac 0
        powercfg.exe -x -monitor-timeout-ac 0
        
        ## Download the bootstrap_azure_**.zip file to C:\scratch
        ## Download git, puppet, and nodes.pp
        Invoke-WebRequest -Uri $ext_src/$puppet -UseBasicParsing -OutFile "$env:systemdrive\$puppet"
        Invoke-WebRequest -Uri $ext_src/$git -UseBasicParsing -OutFile "$env:systemdrive\$git"
        Invoke-WebRequest -Uri $ext_src/$manifest -UseBasicParsing -OutFile "$local_dir\$manifest"

        ## Install Git
        Start-Process "$env:systemdrive\$git" /verysilent -Wait
        Write-Log -message  ('{0} :: Git installed " {1}' -f $($MyInvocation.MyCommand.Name), $git) -severity 'DEBUG'
        Write-Host ('{0} :: Git installed :: {1}' -f $($MyInvocation.MyCommand.Name), $git)

        ## Install Puppet
        Start-Process msiexec -ArgumentList @("/qn", "/norestart", "/i", "$env:systemdrive\$puppet") -Wait
        Write-Log -message  ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet) -severity 'DEBUG'
        Write-Host ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet)
        if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
            Write-Host "Did not install puppet"
            exit 1
        }
        $env:PATH += ";C:\Program Files\Puppet Labs\Puppet\bin"
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Function Set-DCRoninRepo {
    param (
        [string] $ronin_repo = "$env:systemdrive\ronin",
        [string] $nodes_def_src = "$env:systemdrive\BootStrap\nodes.pp",
        [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes.pp",
        [string] $bootstrap_dir = "$env:systemdrive\BootStrap\",
        [string] $secret_src = "$env:systemdrive\programdata\secrets\",
        [string] $secrets = "$env:systemdrive\ronin\data\secrets",
        [String] $sentry_reg = "HKLM:SYSTEM\CurrentControlSet\Services",
        [string] $workerType = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").workerType,
        [string] $role = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").role,
        [string] $sourceOrg = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Organisation,
        [string] $sourceRepo = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Repository,
        [string] $sourceBranch = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Branch,
        [string] $secret_file = "$env:systemdrive\ronin\data\secrets\vault.yaml"
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        If (!(test-path $env:systemdrive\ronin)) {
            git clone --single-branch --branch $sourceBranch https://github.com/$sourceOrg/$sourceRepo $ronin_repo
            $git_exit = $LastExitCode
            if ($git_exit -eq 0) {
                Write-Log -message  ('{0} :: Cloned from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceBranch)) -severity 'DEBUG'
            }
            else {
                Write-Log -message  ('{0} :: Git clone failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceBranch)) -severity 'DEBUG'
                DO {
                    Start-Sleep -s 15
                    git clone  --single-branch --branch $sourceBranch https://github.com/$sourceOrg/$sourceRepo $ronin_repo
                    $git_exit = $LastExitCode
                } Until ( $git_exit -eq 0)
            }
            Set-Location $ronin_repo
            Write-Log -message  ('{0} ::Ronin Puppet HEAD is set to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
        }
        if (!(Test-path $nodes_def)) {
            Copy-item -path $nodes_def_src -destination $nodes_def -force
            (Get-Content -path $nodes_def) -replace 'roles::role', "roles::$role" | Set-Content $nodes_def
        }
        if (!(Test-path $secrets)) {
            mkdir $secrets
            Copy-item -path "$secret_src\*" -destination $secrets -recurse -force
        }
        # Start to disable Windows defender here
        $caption = ((Get-WmiObject Win32_OperatingSystem).caption)
        $caption = $caption.ToLower()
        $os_caption = $caption -replace ' ', '_'
        if ($os_caption -like "*windows_10*") {
            ## This didn't work in windows 11, permissions issue. Will only run on Windows 10.
            Set-ItemProperty -Path "$sentry_reg\SecurityHealthService" -name "start" -Value '4' -Type Dword
        }
        if ($os_caption -notlike "*2012*") {
            Set-ItemProperty -Path "$sentry_reg\sense" -name "start" -Value '4' -Type Dword
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

function Apply-DCRoninPuppet {
    param (
        [int] $exit,
        [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
        [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
        [string] $puppetfile = "$env:systemdrive\ronin\Puppetfile",
        [string] $logdir = "$env:systemdrive\logs",
        [string] $ed_key = "$env:systemdrive\generic-worker\ed25519-private.key",
        [string] $datetime = (get-date -format yyyyMMdd-HHmm),
        [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
        [string] $ronnin_key = "$mozilla_key\ronin_puppet",
        [string] $worker_pool = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").worker_pool_id,
        [string] $sourceOrg = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Organisation,
        [string] $sourceRepo = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Repository,
        [string] $sourceBranch = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Branch,
        [string] $stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {

        Set-Location $env:systemdrive\ronin
        If (!(test-path $logdir\old)) {
            New-Item -ItemType Directory -Force -Path $logdir\old
        }
        git pull https://github.com/$sourceOrg/$sourceRepo $sourceBranch
        Write-Log -message  ('{0} ::Ronin Puppet HEAD is set to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'

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

        if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
            if (($last_exit -eq 0) -or ($puppet_exit -eq 2)) {
                Write-Log -message  ('{0} :: Puppet apply failed 1st run.  ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
                Move-StrapPuppetLogs
                shutdown ('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
            }
            elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
                Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
                Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Move-StrapPuppetLogs
                shutdown @('-r', '-t', '1200', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
            }
        }
        elseif (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
            Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
            Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
            Move-StrapPuppetLogs
            Write-Log -message  ('{0} :: Puppet apply successful. Waiting on Cloud-Image-Builder pickup' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap complete', '-f', '-d', '4:5')
        }
        else {
            Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $last_exit
            Start-sleep -s 300
            Move-StrapPuppetLogs
            shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Start-AzRoninPuppet {
    param (
        [int] $exit,
        [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
        [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
        [string] $puppetfile = "$env:systemdrive\ronin\Puppetfile",
        [string] $logdir = "$env:systemdrive\logs",
        [string] $ed_key = "$env:systemdrive\generic-worker\ed25519-private.key",
        [string] $datetime = (get-date -format yyyyMMdd-HHmm),
        [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
        [string] $ronnin_key = "$mozilla_key\ronin_puppet",
        [string] $worker_pool = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").worker_pool_id,
        [string] $stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage,
        [string] $deploymentId = $ENV:deploymentId
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        Write-Host ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime())
    }
    process {

        Set-Location $env:systemdrive\ronin
        If ( -Not (test-path $logdir\old)) {
            New-Item -ItemType Directory -Force -Path $logdir\old
        }
        Write-Log -message ('{0} :: Ronin Puppet HEAD is set to {1}' -f $($MyInvocation.MyCommand.Name), $deploymentID) -severity 'DEBUG'
        Write-host ('{0} :: Ronin Puppet HEAD is set to {1}' -f $($MyInvocation.MyCommand.Name), $deploymentID)

        Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'inprogress'

        # Setting Env variabes for PuppetFile install and Puppet run
        # The ssl variables are needed for R10k
        Write-Log -message ('{0} :: Setting Puppet enviroment.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Write-host ('{0} :: Setting Puppet enviroment.' -f $($MyInvocation.MyCommand.Name))

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

        Write-Log -message ('{0} :: Moving old logs.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Write-host ('{0} :: Moving old logs.' -f $($MyInvocation.MyCommand.Name))
        Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
        Write-Log -message  ('{0} :: Running Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $logdir\$datetime-bootstrap-puppet.log,$logdir\$datetime-bootstrap-puppet.json
        [int]$puppet_exit = $LastExitCode
        ## https://www.puppet.com/docs/puppet/6/man/apply.html#options
        
        switch ($puppet_exit) {
            0 {
                Write-Log -message  ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
                Set-ItemProperty -Path $ronnin_key -Name 'bootstrap_stage' -Value 'complete'
                #Move-StrapPuppetLogs
                if ($worker_pool -like "trusted*") {
                    if (Test-Path -Path $ed_key) {
                        Remove-Item  $ed_key -force
                    }
                    while (!(Test-Path $ed_key)) {
                        Write-Log -message  ('{0} :: Trusted image. Waiting on CoT key. Human intervention needed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                        Start-Sleep -seconds 15
                    }
                    # Provide a window for the file to be writen
                    Start-Sleep -seconds 30
                    Write-Log -message  ('{0} :: Trusted image. Blocking livelog outbound access.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                    New-NetFirewallRule -DisplayName "Block LiveLog" -Direction Outbound -Program "c:\generic-worker\livelog.exe" -Action block
                }
                exit 0
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
                Move-StrapPuppetLogs
                exit 1
            }
            2 {
                Write-Log -message ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
                Set-ItemProperty -Path $ronnin_key -Name 'bootstrap_stage' -Value 'complete'
                #Move-StrapPuppetLogs
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
                    Write-Host $psitem
                }
                Move-StrapPuppetLogs
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
                    Write-Host $psitem
                }
                Move-StrapPuppetLogs
                exit 6
            }
            Default {
                Write-Log -message  ('{0} :: Unable to determine state post Puppet apply :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $last_exit
                #Start-sleep -s 300
                #Move-StrapPuppetLogs
                exit 1
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
        [string] $src_Organisation,
        [string] $src_Repository,
        [string] $src_Revision
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
        Invoke-WebRequest https://raw.githubusercontent.com/$src_Organisation/$src_Repository/$src_branch/provisioners/windows/$image_provisioner/bootstrap.ps1 -OutFile "$env:systemdrive\BootStrap\bootstrap-src.ps1" -UseBasicParsing
        Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\bootstrap.ps1
        Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

$worker_pool_id = 'win11-64-2009-hw-ref-alpha'
$base_image = 'win11642009hwrefalpha'
$src_Organisation = 'jwmoss'
$src_Repository = 'ronin_puppet'
$src_Branch = 'win11'
$image_provisioner = 'OSDCloud'

Write-Output ("Processing {0}" -f $ENV:COMPUTERNAME)
Write-Host "Processing $($ENV:computername)"

## Check that the bootstrap tasks exists
$taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -like "bootstrap" }

## Try and install windows updates here
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module PSWindowsUpdate -Force
Import-Module PSWindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot | Out-File "C:\Windows\PSWindowsUpdate.log"

## If the task does not exist, setup logging and install the scheduled task of this script to run on start
if (-Not ($taskExists)) {
    Write-Log -message  ('{0} :: Bootstrap started. Waiting to allow OS installation to complete.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Write-Host "Bootstrap started. Waiting to allow OS installation to complete"
    Start-Sleep -s 120
    ## Creates C:\bootstrap, installs nxlog, nxlog conf file, and nxlog certificate
    Set-Logging
    Bootstrap-schtasks -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision -image_provisioner $image_provisioner
    shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap task is in place', '-f', '-d', '4:5')
    while ($true) {
        Start-Sleep -s 60
        Write-Log -message  ('{0} :: Last reboot failed. Attempting again..' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        #shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap task is in place', '-f', '-d', '4:5')
    }
}
If (-Not (test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet')) {
    # Waiting to let things settle out
    Write-Log -message  ('{0} :: Bootstrap started. Waiting to allow OS installation to complete.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Install-DCPrerequ -DisableNameChecking
    Start-Sleep -s 120
    $puppet = (get-command puppet -ErrorAction SilentlyContinue)
    $git = (get-command git -ErrorAction SilentlyContinue)
    #if ((!($puppet)) -or (!($git))) {
    #Install-DCPrerequ -DisableNameChecking
    #Write-Log -message  ('{0} :: Reboot; Prereques installed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    #shutdown @('-r', '-t', '0', '-c', 'Reboot; Prerequisites in place, logging setup', '-f', '-d', '4:5')
    #}
    Set-RoninRegOptions -DisableNameChecking -worker_pool_id $worker_pool_id -base_image $base_image -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Branch $src_Branch -image_provisioner $image_provisioner
    Write-Log -message  ('{0} :: Reboot; Prerequisites in place and registry options have been set.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    shutdown @('-r', '-t', '0', '-c', 'Reboot; Prerequisites in place and registry options have been set.', '-f', '-d', '4:5')
    # while ($true) {
    #     Start-Sleep -s 60
    #     Write-Log -message  ('{0} :: Last reboot failed. Attempting again..' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    #     shutdown @('-r', '-t', '0', '-c', 'Reboot; Prerequisites in place and registry options have been set.', '-f', '-d', '4:5')
    # }
}
## If the ronin_puppet key exists, check the bootstrap_stage
If (test-path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet') {
    $stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
}
If (($stage -eq 'setup') -or ($stage -eq 'inprogress')) {
    Set-DCRoninRepo -DisableNameChecking
    Apply-DCRoninPuppet -DisableNameChecking
    shutdown @('-r', '-t', '0', '-c', 'Reboot; Prerequisites in place, logging setup, and registry setup', '-f', '-d', '4:5')
}
If ($stage -eq 'complete') {
    Write-Log -message  ('{0} ::Bootstrapping appears complete' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    # $caption = ((Get-WmiObject Win32_OperatingSystem).caption)
    # $caption = $caption.ToLower()
    # $os_caption = $caption -replace ' ', '_'
    # if ($os_caption -like "*windows_13*") {
    #     ## Target only windows 11 for tests at this time.
    #     Import-Module "$env:systemdrive\ronin\provisioners\windows\modules\Bootstrap\Bootstrap.psm1"
    #     Write-Output ("Processing {0}" -f $ENV:COMPUTERNAME)
    #     ## Remove old version of pester and install new version if not already running 5
    #     if ((Get-Module -Name Pester -ListAvailable).version.major -ne 5) {
    #         Set-PesterVersion
    #     }
    #     ## Change directory to tests
    #     Set-Location $env:systemdrive\ronin\test\integration\windows11
    #     ## Loop through each test and run it
    #     Get-ChildItem *.tests* | ForEach-Object {
    #         Invoke-RoninTest -Test $_.Fullname
    #     }
    # }
    exit 0
}