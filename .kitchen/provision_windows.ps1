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
    '--show_diff' `
    '--debug'

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
