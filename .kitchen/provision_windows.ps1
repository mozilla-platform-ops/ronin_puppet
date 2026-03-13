param(
    [switch]$AsSystem
)

$ErrorActionPreference = 'Stop'

function Invoke-AsSystem {
    $taskName = 'KitchenProvisionAsSystem'
    $scriptPath = 'C:\Windows\Temp\kitchen-provision-system.ps1'
    $wrapperPath = 'C:\Windows\Temp\kitchen-provision-system.cmd'
    $logPath = 'C:\Windows\Temp\kitchen-provision-system.log'
    $exitPath = 'C:\Windows\Temp\kitchen-provision-system.exitcode'

    Copy-Item -Path $PSCommandPath -Destination $scriptPath -Force

    @(
        '@echo off',
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$scriptPath"" -AsSystem > ""$logPath"" 2>&1",
        "echo %ERRORLEVEL% > ""$exitPath""",
        'exit /b %ERRORLEVEL%'
    ) | Set-Content -Path $wrapperPath -Encoding ASCII -Force

    Remove-Item $logPath, $exitPath -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$wrapperPath`""
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)

    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName

    $deadline = (Get-Date).AddMinutes(50)
    while (-not (Test-Path $exitPath)) {
        if ((Get-Date) -gt $deadline) {
            throw 'Timed out waiting for SYSTEM provision task to finish.'
        }
        Start-Sleep -Seconds 5
    }

    if (Test-Path $logPath) {
        Get-Content -Path $logPath -ErrorAction SilentlyContinue | Write-Host
    }

    $exitCode = $null
    $parseDeadline = (Get-Date).AddSeconds(30)
    while ($null -eq $exitCode -and (Get-Date) -lt $parseDeadline) {
        $exitRaw = Get-Content -Path $exitPath -Raw -ErrorAction SilentlyContinue
        if ($null -ne $exitRaw) {
            $exitRaw = $exitRaw.Trim()
            if ($exitRaw -match '^\d+$') {
                $exitCode = [int]$exitRaw
                break
            }
        }
        Start-Sleep -Seconds 1
    }

    if ($null -eq $exitCode) {
        throw "Unable to parse SYSTEM provision task exit code from $exitPath."
    }

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item $scriptPath, $wrapperPath, $exitPath -ErrorAction SilentlyContinue

    exit $exitCode
}

function Invoke-DebugProbe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    Write-Host "DEBUG [$Description] begin"
    try {
        $output = & $ScriptBlock 2>&1 | Out-String -Width 4096
        if ($output.Trim()) {
            $output.TrimEnd().Split([Environment]::NewLine) | ForEach-Object {
                if ($_) {
                    Write-Host $_
                }
            }
        }
        else {
            Write-Host '(no output)'
        }
    }
    catch {
        Write-Host "DEBUG [$Description] failed: $($_.Exception.Message)"
    }
    Write-Host "DEBUG [$Description] end"
}

function Write-GitDebugState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Phase
    )

    $programFilesX86 = ${env:ProgramFiles(x86)}

    Write-Host "DEBUG [$Phase] ProgramFiles=$env:ProgramFiles"
    Write-Host "DEBUG [$Phase] ProgramW6432=$env:ProgramW6432"
    Write-Host "DEBUG [$Phase] ProgramFiles(x86)=$programFilesX86"
    Write-Host "DEBUG [$Phase] PATH=$env:PATH"

    Invoke-DebugProbe -Description "$Phase facter custom_win_git_version" -ScriptBlock {
        & "$puppetBin\facter.bat" custom_win_git_version
    }

    Invoke-DebugProbe -Description "$Phase facter --debug custom_win_git_version" -ScriptBlock {
        & "$puppetBin\facter.bat" --debug custom_win_git_version
    }

    Invoke-DebugProbe -Description "$Phase external fact facts_win_other_apps.ps1" -ScriptBlock {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\ronin_puppet\modules\win_shared\facts.d\facts_win_other_apps.ps1'
    }

    Invoke-DebugProbe -Description "$Phase Git path checks" -ScriptBlock {
        [pscustomobject]@{
            program_files_git      = Test-Path "$env:ProgramFiles\Git\bin\git.exe"
            program_w6432_git      = if ($env:ProgramW6432) { Test-Path "$env:ProgramW6432\Git\bin\git.exe" } else { $null }
            program_files_x86_git  = if ($programFilesX86) { Test-Path "$programFilesX86\Git\bin\git.exe" } else { $null }
        } | Format-List
    }

    Invoke-DebugProbe -Description "$Phase Get-Command git.exe" -ScriptBlock {
        Get-Command git.exe -All -ErrorAction SilentlyContinue | Select-Object Source, Version | Format-List
    }

    Invoke-DebugProbe -Description "$Phase Git file version details" -ScriptBlock {
        $gitCandidates = @(
            "$env:ProgramFiles\Git\bin\git.exe",
            $(if ($env:ProgramW6432) { "$env:ProgramW6432\Git\bin\git.exe" }),
            $(if ($programFilesX86) { "$programFilesX86\Git\bin\git.exe" })
        ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

        if (-not $gitCandidates) {
            Write-Host 'No Git executable paths found.'
            return
        }

        $gitCandidates | ForEach-Object {
            Get-Item $_ | Select-Object FullName, @{ Name = 'ProductVersion'; Expression = { $_.VersionInfo.ProductVersion } }
        } | Format-List
    }

    Invoke-DebugProbe -Description "$Phase Chocolatey local packages matching git" -ScriptBlock {
        $choco = Get-Command choco.exe -ErrorAction SilentlyContinue
        if (-not $choco) {
            Write-Host 'choco.exe not found on PATH.'
            return
        }

        & $choco.Source list --local-only git
    }

    Invoke-DebugProbe -Description "$Phase uninstall registry entries matching Git" -ScriptBlock {
        $gitEntries = Get-ItemProperty `
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', `
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' `
            -ErrorAction SilentlyContinue |
            Where-Object { $PSItem.DisplayName -match 'Git' } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallLocation

        if (-not $gitEntries) {
            Write-Host 'No uninstall registry entries matching Git.'
            return
        }

        $gitEntries | Format-List
    }
}

$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if (-not $AsSystem -and $currentIdentity -ne 'NT AUTHORITY\SYSTEM') {
    Write-Host "Current identity is $currentIdentity; relaunching provisioner as SYSTEM..."
    Invoke-AsSystem
}

# Install OpenVox agent
Write-Host "Downloading OpenVox agent..."
$msiUrl = "https://downloads.voxpupuli.org/windows/openvox8/openvox-agent-8.25.0-x64.msi"
$msiPath = "C:\openvox-agent.msi"
Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing

Write-Host "Installing OpenVox agent..."
Start-Process msiexec -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -NoNewWindow
Write-Host "OpenVox agent installed."

# Set up environment matching Start-AzRoninPuppet.ps1
$puppetBin = "$env:ProgramFiles\Puppet Labs\Puppet\bin"
$env:PATH = "$puppetBin;$env:PATH"
$env:SSL_CERT_FILE = "$env:ProgramFiles\Puppet Labs\Puppet\puppet\ssl\certs\ca.pem"
$env:SSL_CERT_DIR = "$env:ProgramFiles\Puppet Labs\Puppet\puppet\ssl\certs"
$env:FACTER_env_windows_installdir = "$env:ProgramFiles\Puppet Labs\Puppet"
$env:PL_BASEDIR = "$env:ProgramFiles\Puppet Labs\Puppet"
$env:PUPPET_DIR = "$env:ProgramFiles\Puppet Labs\Puppet"
$env:RUBYLIB = "$env:ProgramFiles\Puppet Labs\Puppet\lib"
$env:HOMEPATH = "\Users\Administrator"
$env:HOMEDRIVE = "C:"
$env:USERNAME = "Administrator"
$env:USERPROFILE = "C:\Users\Administrator"

# Download ronin_puppet at the current commit SHA
Write-Host "Downloading ronin_puppet at ref $env:RONIN_REF..."
$zipUrl = "https://github.com/mozilla-platform-ops/ronin_puppet/archive/$env:RONIN_REF.zip"
Invoke-WebRequest -Uri $zipUrl -OutFile C:\ronin_puppet.zip -UseBasicParsing

Write-Host "Extracting ronin_puppet..."
Expand-Archive -Path C:\ronin_puppet.zip -DestinationPath C:\ -Force
$repoDir = Get-ChildItem C:\ -Directory | Where-Object { $_.Name -like 'ronin_puppet-*' } | Select-Object -First 1
if (Test-Path C:\ronin_puppet) { Remove-Item C:\ronin_puppet -Recurse -Force }
Move-Item $repoDir.FullName C:\ronin_puppet
Set-Location C:\ronin_puppet

# Seed registry values that worker-images bootstrap normally sets before Puppet.
$mozillaKey = 'HKLM:\SOFTWARE\Mozilla'
$roninKey = "$mozillaKey\ronin_puppet"
$sourceKey = "$roninKey\source"

$workerPoolId = if ($env:WORKER_POOL_ID) { $env:WORKER_POOL_ID } elseif ($env:PUPPET_ROLE) { $env:PUPPET_ROLE } else { 'kitchen-test' }
$imageProvisioner = if ($env:IMAGE_PROVISIONER) { $env:IMAGE_PROVISIONER } else { 'azure' }
$sourceOrg = if ($env:SRC_ORGANISATION) { $env:SRC_ORGANISATION } else { 'mozilla-platform-ops' }
$sourceRepo = if ($env:SRC_REPOSITORY) { $env:SRC_REPOSITORY } else { 'ronin_puppet' }
$sourceBranch = if ($env:SRC_BRANCH) { $env:SRC_BRANCH } elseif ($env:GITHUB_HEAD_REF) { $env:GITHUB_HEAD_REF } elseif ($env:GITHUB_REF_NAME) { $env:GITHUB_REF_NAME } else { 'test-kitchen' }
$bootstrapStage = if ($env:BOOTSTRAP_STAGE) { $env:BOOTSTRAP_STAGE } else { 'setup' }
$deploymentHash = if ($env:RONIN_REF) { $env:RONIN_REF } else { 'kitchen' }

if (-not (Test-Path $mozillaKey)) {
    New-Item -Path 'HKLM:\SOFTWARE' -Name 'Mozilla' -Force | Out-Null
}
if (-not (Test-Path $roninKey)) {
    New-Item -Path $mozillaKey -Name 'ronin_puppet' -Force | Out-Null
}
New-Item -Path $roninKey -Name 'source' -Force | Out-Null

New-ItemProperty -Path $roninKey -Name 'image_provisioner' -Value $imageProvisioner -PropertyType String -Force | Out-Null
New-ItemProperty -Path $roninKey -Name 'worker_pool_id' -Value $workerPoolId -PropertyType String -Force | Out-Null
New-ItemProperty -Path $roninKey -Name 'role' -Value $env:PUPPET_ROLE -PropertyType String -Force | Out-Null
New-ItemProperty -Path $roninKey -Name 'inmutable' -Value 'false' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $roninKey -Name 'last_run_exit' -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $roninKey -Name 'bootstrap_stage' -Value $bootstrapStage -PropertyType String -Force | Out-Null
New-ItemProperty -Path $roninKey -Name 'GITHASH' -Value $deploymentHash -PropertyType String -Force | Out-Null
New-ItemProperty -Path $sourceKey -Name 'Organisation' -Value $sourceOrg -PropertyType String -Force | Out-Null
New-ItemProperty -Path $sourceKey -Name 'Repository' -Value $sourceRepo -PropertyType String -Force | Out-Null
New-ItemProperty -Path $sourceKey -Name 'Branch' -Value $sourceBranch -PropertyType String -Force | Out-Null

Write-Host "Seeded $roninKey (worker_pool_id=$workerPoolId, role=$env:PUPPET_ROLE, bootstrap_stage=$bootstrapStage)."

# Set Facter variables
$env:FACTER_custom_win_role = $env:PUPPET_ROLE
$env:FACTER_running_in_test_kitchen = 'true'

Write-GitDebugState -Phase 'pre-apply'

# Run puppet apply
# r10k_modules is committed to the repo, so no separate `r10k puppetfile install` is needed.
Write-Host "Running puppet apply for role $env:PUPPET_ROLE..."
& "$puppetBin\puppet" apply `
    -e "include roles_profiles::roles::$env:PUPPET_ROLE" `
    '--modulepath=modules;r10k_modules' `
    '--hiera_config=hiera.yaml' `
    '--onetime' `
    '--verbose' `
    '--no-daemonize' `
    '--no-usecacheonfailure' `
    '--detailed-exitcodes' `
    '--no-splay' `
    '--show_diff'

$exitCode = $LASTEXITCODE

Write-GitDebugState -Phase 'post-apply'

# Handle exit codes the same way as Start-AzRoninPuppet.ps1
# 0 or 2 = success, 1/4/6 = failure
switch ($exitCode) {
    { $_ -in 0, 2 } {
        Write-Host "Puppet apply succeeded (exit code $exitCode)."
        exit 0
    }
    { $_ -in 1, 4, 6 } {
        Write-Host "Puppet apply failed (exit code $exitCode)."
        exit 1
    }
    default {
        Write-Host "Puppet apply exited with unexpected code $exitCode."
        exit $exitCode
    }
}
