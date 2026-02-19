$ErrorActionPreference = 'Stop'

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
