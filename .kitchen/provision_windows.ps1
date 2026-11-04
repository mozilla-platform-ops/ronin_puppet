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

    function Write-NewLogContent {
        param(
            [string]$Path,
            [ref]$Offset
        )

        if (-not (Test-Path $Path)) {
            return
        }

        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            if ($stream.Length -lt $Offset.Value) {
                $Offset.Value = 0
            }

            if ($stream.Length -eq $Offset.Value) {
                return
            }

            $stream.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader = New-Object System.IO.StreamReader($stream)
            try {
                $content = $reader.ReadToEnd()
                if ($content) {
                    $content.TrimEnd("`r", "`n").Split(@("`r`n", "`n"), [System.StringSplitOptions]::None) | ForEach-Object {
                        if ($_) {
                            Write-Host $_
                        }
                    }
                }
            } finally {
                $Offset.Value = $stream.Position
                $reader.Dispose()
            }
        } finally {
            $stream.Dispose()
        }
    }

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
    $logOffset = 0L
    $lastHeartbeat = Get-Date
    while (-not (Test-Path $exitPath)) {
        if ((Get-Date) -gt $deadline) {
            throw 'Timed out waiting for SYSTEM provision task to finish.'
        }

        Write-NewLogContent -Path $logPath -Offset ([ref]$logOffset)

        $now = Get-Date
        if (($now - $lastHeartbeat).TotalSeconds -ge 30) {
            $taskState = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State
            if (-not $taskState) {
                $taskState = 'Unknown'
            }
            Write-Host "SYSTEM provision task still running (state=$taskState, elapsed=$([int](($now - ($deadline.AddMinutes(-50))).TotalSeconds))s)..."
            $lastHeartbeat = $now
        }

        Start-Sleep -Seconds 5
    }

    Write-NewLogContent -Path $logPath -Offset ([ref]$logOffset)

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

# Ensure the Administrator temp directory exists. When running as SYSTEM the
# profile folder may not have been fully created yet, and Facter
# will fail with "No such file or directory" when they try to stat it.
$adminTemp = "C:\Users\Administrator\AppData\Local\Temp"
if (-not (Test-Path $adminTemp)) {
    New-Item -Path $adminTemp -ItemType Directory -Force | Out-Null
}
$env:TEMP = $adminTemp
$env:TMP = $adminTemp

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

# Match production bootstrap: Git is installed before Puppet runs.
function Install-KitchenGit {
    $gitExe = "$env:ProgramFiles\Git\cmd\git.exe"
    if (-not (Test-Path $gitExe)) {
        $installer = Join-Path $env:TEMP ("kitchen-git-" + [guid]::NewGuid().ToString('N') + '.exe')
        try {
            $url = 'https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/Git-2.56.0.2-64-bit.exe'
            for ($attempt = 1; $attempt -le 3; $attempt++) {
                try { Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 300; break }
                catch { if ($attempt -eq 3) { throw }; Start-Sleep -Seconds 10 }
            }
            $process = Start-Process -FilePath $installer -ArgumentList '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES /SP- /o:PathOption=Cmd' -Wait -PassThru
            if ($process.ExitCode -notin 0, 3010) { throw "Git installer failed rc=$($process.ExitCode)" }
            if (-not (Test-Path $gitExe)) { throw 'Git installation did not produce git.exe.' }
        } finally {
            Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        }
    }
    $env:PATH = "$env:ProgramFiles\Git\cmd;$env:PATH"
}
Install-KitchenGit

# Set Facter variables
$env:FACTER_custom_win_role = $env:PUPPET_ROLE
$env:FACTER_running_in_test_kitchen = 'true'

# Apply the image settings, then check that they survive the runtime pool ID.
foreach ($stage in @('image', 'worker')) {
    if ($stage -eq 'worker') {
        $taskDrive = (Get-ItemProperty $roninKey -Name task_drive -ErrorAction SilentlyContinue).task_drive
        if ($taskDrive -ne 'C:') { break }
        Set-ItemProperty $roninKey -Name worker_pool_id -Value "gecko-t/$workerPoolId"
        Set-ItemProperty $roninKey -Name bootstrap_stage -Value 'complete'
    }
    Write-Host "Running puppet apply for role $env:PUPPET_ROLE ($stage)..."
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
    if ($LASTEXITCODE -notin @(0, 2)) {
        Write-Host "Puppet apply failed (exit code $LASTEXITCODE)."
        exit 1
    }
}
# Exercise the boot layout after Puppet convergence, before Pester checks.
if ((Get-ItemProperty $roninKey).work_volume -eq 1) {
    & C:\ronin_puppet\test\powershell\work_volume.ps1
}
exit 0
