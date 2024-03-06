param(
    [string] $worker_pool_id,
    [string] $role,
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Branch,
    [string] $image_provisioner = 'MDC1Windows'
)

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
        [string] $ext_src = "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites",
        [string] $local_dir = "$env:systemdrive\BootStrap",
        [string] $nxlog_msi = "nxlog-ce-2.10.2150.msi",
        [string] $nxlog_conf = "nxlog.conf",
        [string] $nxlog_pem  = "papertrail-bundle.pem",
        [string] $nxlog_dir  = "$env:systemdrive\Program Files (x86)\nxlog"
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        New-Item -ItemType Directory -Force -Path $local_dir -ErrorAction SilentlyContinue

        $maxRetries = 20
		$retryInterval = 3
        if (!(Test-Path $nxlog_dir\nxlog.exe)) {
		    try {
			    for ($retryCount = 1; $retryCount -le $maxRetries; $retryCount++) {
				    if (!(Test-Path $local_dir\$nxlog_msi)) {
					    Invoke-WebRequest  $ext_src/$nxlog_msi -outfile $local_dir\$nxlog_msi -UseBasicParsing
                        break
                    }
                }
            }
            catch {
                Write-Host "Attempt ${retryCount}: An error occurred - $_"
                Write-Host "Retrying in ${retryInterval} seconds..."
                Start-Sleep -Seconds $retryInterval
                if ($retryCount -gt $maxRetries) {
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.MessageBox]::Show("Logging Set Up Failed!!!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    exit 99
                }
            }
            msiexec /i $local_dir\$nxlog_msi /passive
        }
        start-sleep -seconds 3
        try {
            $retryCount = 0
            for ($retryCount = 1; $retryCount -le $maxRetries; $retryCount++) {
                while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
                Invoke-WebRequest  $ext_src/deploy_nxlog.conf -outfile "$nxlog_dir\conf\$nxlog_conf" -UseBasicParsing
                while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
                Invoke-WebRequest  $ext_src/$nxlog_pem -outfile "$nxlog_dir\cert\$nxlog_pem" -UseBasicParsing
			}
		}
		catch {
			Write-Host "Attempt ${retryCount}: An error occurred - $_"
			Write-Host "Retrying in ${retryInterval} seconds..."
			Start-Sleep -Seconds $retryInterval
            if ($retryCount -gt $maxRetries) {
                Add-Type -AssemblyName System.Windows.Forms
                [System.Windows.Forms.MessageBox]::Show("Logging Set Up Failed!!!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                exit 99
            }
		}
		Restart-Service -Name nxlog -force
	}
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Get-PSModules {
    param (
       [array]$modules = @(
                    "ugit",
                    "Powershell-Yaml"
                    )
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
        if ($nugetProvider -eq $null) {
           Write-Log -message  ('{0} :: Installing NuGet Package Provider' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
           Install-PackageProvider -Name NuGet -Force -Confirm:$false
        } else {
           Write-Log -message  ('{0} :: NuGet is present.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }

        foreach ($module in $modules) {
            $hit = Get-Module -Name $module
            Write-Log -message  ('{0} :: Installing {1} module' -f $($MyInvocation.MyCommand.Name,  $module)) -severity 'DEBUG'
            if ($null -eq $hit) {
                Install-Module -Name $module -AllowClobber -Force -Confirm:$false
                if (-not (Get-Module -Name $module -ListAvailable)) {
                    Write-Log -message  ('{0} :: {1} module did not install' -f $($MyInvocation.MyCommand.Name,  $module)) -severity 'DEBUG'
                    write-host exit 3
                }
            } else {
                Write-Log -message  ('{0} :: {1} module is present' -f $($MyInvocation.MyCommand.Name,  $module)) -severity 'DEBUG'
            }
            Import-Module -Name $module -Force -PassThru
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Get-PreRequ {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $azcopy_exe = "D:\applications\azcopy.exe"
        If (-Not (Test-Path $azcopy_exe)) {
        #    New-Item -ItemType Directory -Path "$env:systemdrive\azcopy"
        #    write-host Invoke-WebRequest https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/azcopy-amd64_10.23.0.exe -OutFile "$env:systemdrive\azcopy\azcopy.exe"
        #    write-host Invoke-WebRequest https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/azcopy-amd64_10.23.0.exe -OutFile "$env:systemdrive\azcopy\azcopy-amd64_10.23.0.exe"
        #    Invoke-WebRequest https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/azcopy-amd64_10.23.0.exe -OutFile "$env:systemdrive\azcopy\azcopy.exe"
        #    Invoke-WebRequest https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/azcopy-amd64_10.23.0.exe -OutFile "$env:systemdrive\azcopy\azcopy-amd64_10.23.0.exe"
        }
        Write-Log -message  ('{0} :: Ingesting azcopy creds' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        $creds = ConvertFrom-Yaml -Yaml (Get-Content -Path "D:\secrets\azcredentials.yaml" -Raw)
        $ENV:AZCOPY_SPA_APPLICATION_ID = $creds.azcopy_app_id
        $ENV:AZCOPY_SPA_CLIENT_SECRET = $creds.azcopy_app_client_secret
        $ENV:AZCOPY_TENANT_ID = $creds.azcopy_tenant_id

        If (-Not (Test-Path "$env:systemdrive\puppet-agent-6.28.0-x64.msi")) {
            Write-Log -Message ('{0} :: Downloading Puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'

            Start-Process -FilePath $azcopy_exe -ArgumentList @(
                "copy",
                "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/puppet-agent-6.28.0-x64.msi",
                "$env:systemdrive\puppet-agent-6.28.0-x64.msi"
            ) -Wait -NoNewWindow

            if (-Not (Test-Path "$env:systemdrive\puppet-agent-6.28.0-x64.msi")) {
                Write-Log -Message ('{0} :: Puppet failed to download' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
        }
        If (-Not (Test-Path "$env:systemdrive\Git-2.37.3-64-bit.exe")) {
            Write-Log -Message ('{0} :: Downloading Git' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'

            Start-Process -FilePath $azcopy_exe -ArgumentList @(
            "copy",
            "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/Git-2.37.3-64-bit.exe",
            "$env:systemdrive\Git-2.37.3-64-bit.exe"
            ) -Wait -NoNewWindow

        }
        if (-Not (Test-Path "$env:programfiles\git\bin\git.exe")) {
            Write-Log -Message ('{0} :: Installing git.exe' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Start-Process -FilePath "$env:systemdrive\Git-2.37.3-64-bit.exe" -ArgumentList @(
                "/verysilent"
            ) -Wait #-NoNewWindow
            $env:PATH += ";C:\Program Files\git\bin"
        }
        if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
            ## Install Puppet using ServiceUI.exe to install as SYSTEM
            Write-Log -Message ('{0} :: Installing puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Start-Process msiexec -ArgumentList @("/qn", "/norestart", "/i", "$env:systemdrive\puppet-agent-6.28.0-x64.msi") -Wait
            Write-Log -message  ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), "puppet-agent-6.28.0-x64.msi") -severity 'DEBUG'
            Write-Host ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), "puppet-agent-6.28.0-x64.msi")
            if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
                Write-Host "Did not install puppet"
                write-host exit 1
            }
            $env:PATH += ";C:\Program Files\Puppet Labs\Puppet\bin"
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [System.EnvironmentVariableTarget]::Machine)
        }
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [System.EnvironmentVariableTarget]::Machine)
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Set-Ronin-Registry {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        If ((test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet")) {
            $worker_pool_id = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").worker_pool_id
            $role = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").role
            $src_Organisation = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").Organisation
            $src_Repository = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").Repository
            $src_Branch = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").Branch
            $image_provisioner = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").image_provisioner
        } else {
            Write-Log -Message ('{0} :: Creating HKLM:\SOFTWARE\Mozilla\ronin_puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            New-Item -Path HKLM:\SOFTWARE -Name Mozilla -force
            New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet -force

            Write-Log -Message ('{0} :: Setting HKLM:\SOFTWARE\Mozilla\ronin_puppet values' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            New-Item -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name source -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'image_provisioner' -Value $image_provisioner -PropertyType String -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'worker_pool_id' -Value $worker_pool_id -PropertyType String -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'role' -Value $role -PropertyType String -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'last_run_exit' -Value '0' -PropertyType Dword -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'setup' -PropertyType String -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Organisation' -Value $src_Organisation -PropertyType String -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Repository' -Value $src_Repository -PropertyType String -force
            New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Branch' -Value $src_Branch -PropertyType String -force
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Get-Ronin {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        if (-Not (Test-Path "$env:systemdrive\ronin\LICENSE")) {
            #Write-Log -Message ('{0} :: Cloning {1}' -f $($MyInvocation.MyCommand.Name)), "$src_Organisation/$src_Repository" -severity 'DEBUG'
            write-host git config --global --add safe.directory "C:/ronin"
            write-host git clone "https://github.com/$($src_Organisation)/$($src_Repository)" "$env:systemdrive\ronin"
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

        ## Set nodes.pp
        $content = @"
node default {
    include roles_profiles::roles::$role
}
"@
        Set-Content -Path "$env:systemdrive\ronin\manifests\nodes.pp" -Value $content
        #if (-not (Test-path "$env:systemdrive\ronin\manifests\nodes.pp")) {
        #    Copy-item -Path "$env:systemdrive\BootStrap\nodes.pp" -Destination "$env:systemdrive\ronin\manifests\nodes.pp" -force
        #    (Get-Content -path "$env:systemdrive\ronin\manifests\nodes.pp") -replace 'roles::role', "roles::$role" | Set-Content "$env:systemdrive\ronin\manifests\nodes.pp"
        #}
        ## Copy the secrets from the image (from osdcloud) to ronin data secrets
        if (-Not (Test-path "$env:systemdrive\ronin\data\secrets")) {
            New-Item -Path "$env:systemdrive\ronin\data" -Name "secrets" -ItemType Directory -Force
            Copy-item -path "D:\secrets\vault.yaml" -destination "$env:systemdrive\ronin\data\secrets\vault.yaml" -force
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Run-Ronin-Run {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {

        Set-Location $env:systemdrive\ronin
        If (-Not (test-path $env:systemdrive\logs\old)) {
            New-Item -ItemType Directory -Force -Path $env:systemdrive\logs\old
        }
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

        $ronnin_key  =  "HKLM:\SOFTWARE\Mozilla\ronin_puppet"
        $logdir = "$env:systemdrive\logs"

        #Get-ChildItem -Path $env:systemdrive\logs\*.log -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue
        Get-ChildItem -Path $env:systemdrive\logs\*.json -Recurse -ErrorAction SilentlyContinue | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue

        $logDate = $(get-date -format yyyyMMdd-HHmm)

        Write-Log -Message ('{0} :: Running Puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $env:systemdrive\logs\$($logdate)-bootstrap-puppet.json
        [int]$puppet_exit = $LastExitCode
        Write-Log -Message ('{0} :: Puppet error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'


        switch ($puppet_exit) {
            0 {
                Write-Log -message  ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply succeeded with no changes or failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -name last_run_exit -value $puppet_exit
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'complete'
                ## this should be in Puppet
                #slmgr.vbs -skms "KMS02.ad.mozilla.com:1688"
                #slmgr.vbs -ato
                Restart-Computer -Confirm:$false -Force
            }
            1 {
                Write-Log -message ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path $ronnin_key -name "last_run_exit" -value $puppet_exit
                ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
                Add-Content -Path "$logdir\$logdate-bootstrap-puppet.json" "]"
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
                Handle-Failure
            }
            2 {
                Write-Log -message ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply succeeded, and some resources were changed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -name last_run_exit -value $puppet_exit
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'complete'
                #slmgr.vbs -skms "KMS02.ad.mozilla.com:1688"
                #slmgr.vbs -ato
                Restart-Computer -Confirm:$false -Force
            }
            4 {
                Write-Log -message ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply succeeded, but some resources failed :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
                ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
                Add-Content -Path "$logdir\$logdate-bootstrap-puppet.json" "]"
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
                Handle-Failure
            }
            6 {
                Write-Log -message ('{0} :: Puppet apply succeeded, but included changes and failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Write-Host ('{0} :: Puppet apply succeeded, but included changes and failures :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit)
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $puppet_exit
                ## The JSON file isn't formatted correctly, so add a ] to complete the json formatting and then output warnings or errors
                Add-Content -Path "$logdir\$logdate-bootstrap-puppet.json" "]"

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
                Handle-Failure
            }
            Default {
                Write-Log -message  ('{0} :: Unable to determine state post Puppet apply :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $last_exit
                Restart-Computer -Confirm:$false -Force
                exit 1
            }
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Set-SCHTask {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Set-PXE {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
		$temp_dir = "$env:systemdrive\temp\"
        New-Item -ItemType Directory -Force -Path $temp_dir -ErrorAction SilentlyContinue

		bcdedit /enum firmware > $temp_dir\firmware.txt

		$fwbootmgr = Select-String -Path "$temp_dir\firmware.txt" -Pattern "{fwbootmgr}"
		if (!$fwbootmgr){
			Write-Log -message  ('{0} :: Device is configured for Legacy Boot. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			Exit 999
		}
		Try{
			# Get the line of text with the GUID for the PXE boot option.
			# IPV4 = most PXE boot options
			# EFI Network = Hyper-V PXE boot option
			$FullLine = (( Get-Content $temp_dir\firmware.txt | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop ).context.precontext)[0]

			# Remove all text but the GUID
			$GUID = '{' + $FullLine.split('{')[1]

			# Add the PXE boot option to the top of the boot order on next boot
			bcdedit /set "{fwbootmgr}" bootsequence "$GUID"

			Write-Log -message  ('{0} :: Device will PXE boot. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			Restart-Computer -Force
		}
		Catch {
			Write-Log -message  ('{0} :: Unable to set next boot to PXE. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			Exit 888
		}
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Handle-Failure {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        If (!(test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet\failure")) {
			Write-Log -message  ('{0} :: Bootstrapping has failed. Attempt 1 of 2. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'failure' -Value "yes" -PropertyType String -force
			Restart-Computer -Force
		} else {
			Write-Log -message  ('{0} :: Bootstrapping has failed. Attempt 2 of 2.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			Set-PXE
		}
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

## prevent standby and monitor timeout during bootstrap
powercfg.exe -x -standby-timeout-ac 0
powercfg.exe -x -monitor-timeout-ac 0

$stage =  (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage

If ($stage -ne 'complete') {
    Setup-Logging
    Set-SCHTask
    Get-PSModules

    Get-PreRequ
    Set-Ronin-Registry
    Get-Ronin
    Run-Ronin-Run
}
exit
