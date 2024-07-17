param(
    [string] $worker_pool_id,
    [string] $role,
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Branch,
    [string] $hash,
    [string] $secret_date,
    [string] $puppet_version,
    [string] $image_provisioner = 'MDC1Windows'
)

# Copied from https://github.com/actions/runner-images
function Invoke-DownloadWithRetry {
    <#
    .SYNOPSIS
        Downloads a file from a given URL with retry functionality.

    .DESCRIPTION
        The Invoke-DownloadWithRetry function downloads a file from the specified URL
        to the specified path. It includes retry functionality in case the download fails.

    .PARAMETER Url
        The URL of the file to download.

    .PARAMETER Path
        The path where the downloaded file will be saved. If not provided, a temporary path
        will be used.

    .EXAMPLE
        Invoke-DownloadWithRetry -Url "https://example.com/file.zip" -Path "C:\Downloads\file.zip"
        Downloads the file from the specified URL and saves it to the specified path.

    .EXAMPLE
        Invoke-DownloadWithRetry -Url "https://example.com/file.zip"
        Downloads the file from the specified URL and saves it to a temporary path.

    .OUTPUTS
        The path where the downloaded file is saved.
    #>

    Param
    (
        [Parameter(Mandatory)]
        [string] $Url,
        [Alias("Destination")]
        [string] $Path
    )

    if (-not $Path) {
        $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
        $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
        $fileName = [IO.Path]::GetFileName($Url) -replace $re

        if ([String]::IsNullOrEmpty($fileName)) {
            $fileName = [System.IO.Path]::GetRandomFileName()
        }
        $Path = Join-Path -Path "${env:Temp}" -ChildPath $fileName
    }

    Write-Host "Downloading package from $Url to $Path..."
    Write-Log -message ('{0} :: Downloading {1} to {2} - {3:o}' -f $($MyInvocation.MyCommand.Name), $url, $path, (Get-Date).ToUniversalTime()) -severity 'DEBUG'

    $interval = 30
    $downloadStartTime = Get-Date
    for ($retries = 20; $retries -gt 0; $retries--) {
        try {
            $attemptStartTime = Get-Date
            (New-Object System.Net.WebClient).DownloadFile($Url, $Path)
            $attemptSeconds = [math]::Round(($(Get-Date) - $attemptStartTime).TotalSeconds, 2)
            Write-Host "Package downloaded in $attemptSeconds seconds"
            Write-Log -message ('{0} :: Package downloaded in {1} seconds - {2:o}' -f $($MyInvocation.MyCommand.Name), $attemptSeconds, (Get-Date).ToUniversalTime()) -severity 'DEBUG'
            break
        } catch {
            $attemptSeconds = [math]::Round(($(Get-Date) - $attemptStartTime).TotalSeconds, 2)
            Write-Warning "Package download failed in $attemptSeconds seconds"
            Write-Log -message ('{0} :: Package download failed in {1} seconds - {2:o}' -f $($MyInvocation.MyCommand.Name), $attemptSeconds, (Get-Date).ToUniversalTime()) -severity 'DEBUG'

            Write-Warning $_.Exception.Message

            if ($_.Exception.InnerException.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
                Write-Warning "Request returned 404 Not Found. Aborting download."
                Write-Log -message ('{0} :: Request returned 404 Not Found. Aborting download. - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
                $retries = 0
            }
        }

        if ($retries -eq 0) {
            $totalSeconds = [math]::Round(($(Get-Date) - $downloadStartTime).TotalSeconds, 2)
            throw "Package download failed after $totalSeconds seconds"
        }

        Write-Warning "Waiting $interval seconds before retrying (retries left: $retries)..."
        Write-Log -message ('{0} :: Waiting {1} seconds before retrying (retries left: {2}})... - {3:o}' -f $($MyInvocation.MyCommand.Name), $interval, $retries, (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        Start-Sleep -Seconds $interval
    }

    return $Path
}

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
        Invoke-DownloadWithRetry $ext_src/$nxlog_msi -Path $local_dir\$nxlog_msi
        #Invoke-WebRequest $ext_src/$nxlog_msi -outfile $local_dir\$nxlog_msi -UseBasicParsing
        msiexec /i $local_dir\$nxlog_msi /passive
        while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
        Invoke-DownloadWithRetry -Url $ext_src/$nxlog_conf -Path "$nxlog_dir\conf\$nxlog_conf"
        #Invoke-WebRequest  $ext_src/$nxlog_conf -outfile "$nxlog_dir\conf\$nxlog_conf" -UseBasicParsing
        while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
        Invoke-DownloadWithRetry -Url $ext_src/$nxlog_pem -Path "$nxlog_dir\cert\$nxlog_pem"
        #Invoke-WebRequest  $ext_src/$nxlog_pem -outfile "$nxlog_dir\cert\$nxlog_pem" -UseBasicParsing
        Restart-Service -Name nxlog -force
    }
    end {
        Write-Host ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime())
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
        [string]
        $puppet_version,
        [string]
        $ext_src = "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites"
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

        if ([string]::IsNullOrEmpty($puppet_version)) {
            $puppet = "puppet-agent-6.28.0-x64.msi"
        }
        else {
            $puppet = ("puppet-agent-{0}-x64.msi") -f $puppet_version
        }

        If (-Not (Test-Path "$env:systemdrive\$puppet")) {
            Write-Log -Message ('{0} :: Downloading Puppet' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'

            Invoke-DownloadWithRetry "$ext_src/$puppet" -Path "$env:systemdrive\$puppet"

            if (-Not (Test-Path "$env:systemdrive\$puppet")) {
                Write-Log -Message ('{0} :: Puppet failed to download' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
        }
        If (-Not (Test-Path "$env:systemdrive\Git-2.37.3-64-bit.exe")) {
            Write-Log -Message ('{0} :: Downloading Git' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'

            Invoke-DownloadWithRetry "$ext_src/Git-2.37.3-64-bit.exe" -Path "$env:systemdrive\Git-2.37.3-64-bit.exe"

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
            Start-Process msiexec -ArgumentList @("/qn", "/norestart", "/i", "$env:systemdrive\$puppet") -Wait
            Write-Log -message  ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet) -severity 'DEBUG'
            Write-Host ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet)
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
            $secret_date = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").secret_date
            $hash = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").GITHASH
        }
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
        New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'GITHASH' -Value $hash -PropertyType String -force
        New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'secret_date' -Value $secret_date -PropertyType String -force
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

        $src_Branch = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").Branch
        $src_Organisation = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").Organisation
        $src_Repository = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").Repository
        $role = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").role
        $hash = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").GITHASH

        $ronin_repo = "$env:systemdrive\ronin"

        if (Test-Path $ronin_repo) {
            Remove-Item $ronin_repo  -Force -Recurse
        }

        if (-Not (Test-Path "$env:systemdrive\ronin\LICENSE")) {
            Write-Log -Message ('{0} :: Cloning {1}' -f $($MyInvocation.MyCommand.Name), "$src_Organisation/$src_Repository") -severity 'DEBUG'
            git config --global --add safe.directory $ronin_repo
            git clone --single-branch --branch $src_Branch https://github.com/$src_Organisation/$src_Repository $ronin_repo
            #git clone --single-branch --branch $src_Branch git://github.com/$src_Organisation/$src_Repository.git $ronin_repo
            git checkout $hash

            ## comment out during testing
            Set-Location $ronin_repo
            if ($debug) {
                Write-Log -message  ('{0} :: Debugging set; pulling latest repo version .' -f $($MyInvocation.MyCommand.Name), ($hash)) -severity 'DEBUG'
            } else {
                git checkout $hash
                Write-Log -message  ('{0} :: Ronin Puppet HEAD is set to {1} .' -f $($MyInvocation.MyCommand.Name), ($hash)) -severity 'DEBUG'
            }

        }


        ## ugit convert git output to pscustomobject
        $branch = git branch | Where-object { $PSItem.isCurrentBranch -eq $true }

        if ($branch -ne $src_branch) {
            git checkout $src_branch
            git pull
            git config --global --add safe.directory "C:/ronin"
            Set-Location $ronin_repo
            git checkout $hash
        }


        ## Set nodes.pp
        $content = @"
node default {
    include roles_profiles::roles::$role
}
"@
        Set-Content -Path "$env:systemdrive\ronin\manifests\nodes.pp" -Value $content

        $secrets_name = $worker_pool_id + "-" + $secret_date + ".yaml"
        New-Item -ItemType Directory -Path "$env:systemdrive\ronin\data\secrets" -Force
        if (Test-Path "$env:systemdrive\ronin\data\secrets") {
            Write-Log -message ('{0} :: Created c:\ronin\data\secrets directory - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        }
        else {
            Write-Log -message ('{0} :: Unable to create c:\ronin\data\secrets directory - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        }
        ## Copy the secrets from the D:\
        #New-Item -Path "$env:systemdrive\ronin\data\secrets" -Name "vault.yaml" -ItemType File -Force
        #$secrets = Get-Content -Path "D:\secrets\$secrets_name"
        #Set-Content -Path "$env:systemdrive\ronin\data\secrets\vault.yaml" -Value $secrets
        Copy-item -path "D:\secrets\$secrets_name" -destination "$env:systemdrive\ronin\data\secrets\vault.yaml" -force
        if (Test-Path "$env:systemdrive\ronin\data\secrets\vault.yaml") {
            Write-Log -message ('{0} :: vault.yml has been created - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
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
                Start-sleep -Seconds 120
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
                Start-sleep -Seconds 120
                Handle-Failure
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
                Start-sleep -Seconds 120
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
                Start-sleep -Seconds 120
                Handle-Failure
            }
            Default {
                Write-Log -message  ('{0} :: Unable to determine state post Puppet apply :: Error code {1}' -f $($MyInvocation.MyCommand.Name), $puppet_exit) -severity 'DEBUG'
                Set-ItemProperty -Path $ronnin_key -name last_run_exit -value $last_exit
                Start-sleep -Seconds 120
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
        if ($debug) {
            pause
            Write-Log -message  ('{0} :: Debug set; pausing on failure. ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
        $failure = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").failure
        If (!($failure)) {
			Write-Log -message  ('{0} :: Bootstrapping has failed. Attempt 1 of 2. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'failure' -Value "yes" -PropertyType String -force
            Start-Sleep -s 10
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

function Set-WinHwRef {
    [CmdletBinding()]
    param (

    )

    ## TODO: This is a temporary workaround until this is moved to puppet.

    ## Check if C:\RelSRE exists, and if it doesn't, create it
    if (-Not (Test-Path "$env:systemdrive\RelSRE")) {
        ## Create the directory to store the files/binaries that will be used in the task-user-init script
        Write-Log -message  ('{0} :: Create C:\RelSRE' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        $null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\RelSRE" -ErrorAction SilentlyContinue
        ## Set permissions for the generic worker task users to read from that directory
        icacls "C:\RelSRE" /grant 'Users:(OI)(CI)R'
        icacls 'C:\RelSRE' /grant 'Administrators:(OI)(CI)F'
    }

    ## Download the Microsoft Store AV1 Plugin locally
    ## Install microsoft store extension
    If (-Not (Test-Path "$env:systemdrive\RelSRE\Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle")) {
        Write-Log -message  ('{0} :: Ingesting azcopy creds' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        $creds = ConvertFrom-Yaml -Yaml (Get-Content -Path "D:\secrets\azcredentials.yaml" -Raw)
        $ENV:AZCOPY_SPA_APPLICATION_ID = $creds.azcopy_app_id
        $ENV:AZCOPY_SPA_CLIENT_SECRET = $creds.azcopy_app_client_secret
        $ENV:AZCOPY_TENANT_ID = $creds.azcopy_tenant_id

        Write-Log -Message ('{0} :: Downloading av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'

        Start-Process -FilePath "D:\applications\azcopy.exe" -ArgumentList @(
            "copy",
            "https://roninpuppetassets.blob.core.windows.net/binaries/Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle",
            "$env:systemdrive\RelSRE\Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle"
        ) -Wait -NoNewWindow
        Write-Log -Message ('{0} :: Downloaded av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }
}

function Set-RemoteConnectivity {
    [CmdletBinding()]
    param (

    )

    ## OpenSSH
    $sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($null -eq $sshdService) {
        Write-Log -message ('{0} :: Enabling OpenSSH.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Start-Service sshd
        Set-Service -Name sshd -StartupType Automatic
        New-NetFirewallRule -Name "AllowSSH" -DisplayName "Allow SSH" -Description "Allow SSH traffic on port 22" -Profile Any -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22
    } else {
        Write-Log -message ('{0} :: SSHd is running.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        if ($sshdService.Status -ne 'Running') {
            Start-Service sshd
            Set-Service -Name sshd -StartupType Automatic
        } else {
            Write-Log -message ('{0} :: SSHD service is already running.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
    }
    ## WinRM
    Write-Log -message ('{0} :: Enabling WinRM.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $adapter = Get-NetAdapter | Where-Object { $psitem.name -match "Ethernet" }
    $network_category = Get-NetConnectionProfile -InterfaceAlias $adapter.Name
    ## WinRM only works on the the active network interface if it is set to private
    if ($network_category.NetworkCategory -ne "Private") {
        Set-NetConnectionProfile -InterfaceAlias $adapter.name -NetworkCategory "Private"
        Enable-PSRemoting -Force
    }

}

## If debug will prevent git hash locking, some reboots and PXE boot fall back
#$debug = $true

## Write out the variables
Write-Host "Worker Pool ID: $worker_pool_id"
Write-Host "Role: $role"
Write-Host "Source Organisation: $src_Organisation"
Write-Host "Source Repository: $src_Repository"
Write-host "Source Branch: $src_Branch"
Write-Host "Hash: $hash"
Write-host "Secret Date: $secret_date"
Write-Host "Image Provisioner: $image_provisioner"

## Add a 10 second delay to view the variables above
Start-sleep -Seconds 10

Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

## prevent standby and monitor timeout during bootstrap
powercfg.exe -x -standby-timeout-ac 0
powercfg.exe -x -monitor-timeout-ac 0

pause

## Enable OpenSSH and WinRM
## Installation through Puppet is is intermittent.
## It works here, but ultimately should be done through Puppet.
Set-RemoteConnectivity

## This is not being set yet, so it won't find the ronin_puppet registry entry
$stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage

If ($stage -ne 'complete') {
    Set-Logging
    Set-SCHTask
    Get-PSModules
    ## TODO: Figure out a way to install binaries/files as taskuser without defaulting to task-user-init
    switch ($role) {
        "win11642009hwref" {
            Write-Log -message  ('{0} :: Setting puppet role {1} bootstrap steps' -f $($MyInvocation.MyCommand.Name), $role) -severity 'DEBUG'
            Set-WinHwRef
        }
        "win11642009hwrefalpha" {
            Write-Log -message  ('{0} :: Setting puppet role {1} bootstrap steps' -f $($MyInvocation.MyCommand.Name), $role) -severity 'DEBUG'
            Set-WinHwRef
        }
        Default {
            Write-Log -message  ('{0} :: Skipping puppet role specific bootstrap steps' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
    }
    Get-PreRequ -puppet_version $puppet_version
    Set-Ronin-Registry
    Get-Ronin
    Run-Ronin-Run
}
exit
