$worker_pool_id = 'win11-64-2009-hw-ref-alpha'
$role = "win11642009hwref"
$base_image = 'win11642009hwref'
$src_Organisation = 'jwmoss'
$src_Repository = 'ronin_puppet'
$src_Branch = 'win11'
$image_provisioner = 'OSDCloud'

Write-host "Starting bootstrap using raw powershell scripts"

## Setup logging and create c:\bootstrap
Write-host "Setup logging and create c:\bootstrap on $ENV:COMPUTERNAME"
$null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue
Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog-ce-2.10.2150.msi" -outfile "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" -UseBasicParsing
msiexec /i "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" /passive
while (!(Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog.conf" -outfile "$env:systemdrive\Program Files (x86)\nxlog\conf\nxlog.conf" -UseBasicParsing
while (!(Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/papertrail-bundle.pem" -outfile "$env:systemdrive\Program Files (x86)\nxlog\cert\papertrail-bundle.pem" -UseBasicParsing
Restart-Service -Name nxlog -force

pause

## Download it
Write-host "Downloading bootstrap script to c:\bootstrap on $ENV:COMPUTERNAME"
Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
Invoke-WebRequest "https://raw.githubusercontent.com/jwmoss/ronin_puppet/win11/provisioners/windows/OSDCloud/bootstrap_test.ps1" -OutFile "$env:systemdrive\BootStrap\bootstrap-src.ps1" -UseBasicParsing
Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\bootstrap.ps1
#Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f

## Install git, puppet, nodes.pp
powercfg.exe -x -standby-timeout-ac 0
powercfg.exe -x -monitor-timeout-ac 0

pause

## Download the bootstrap_azure_**.zip file to C:\scratch
## Download git, puppet, and nodes.pp
Write-host "Downloading puppet, git, and nodes.pp"
Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/puppet-agent-6.28.0-x64.msi" -UseBasicParsing -OutFile "$env:systemdrive\puppet-agent-6.28.0-x64.msi"
Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/Git-2.37.3-64-bit.exe" -UseBasicParsing -OutFile "$env:systemdrive\Git-2.37.3-64-bit.exe"
Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nodes.pp" -UseBasicParsing -OutFile "$env:systemdrive\bootstrap\nodes.pp"

pause

## Install Git
Write-host "Installing git.exe"
Start-Process -FilePath "$env:systemdrive\Git-2.37.3-64-bit.exe" -ArgumentList @(
    "/verysilent"
) -Wait -NoNewWindow

pause

## Install Puppet
Write-host "Installing puppet"
Start-Process msiexec -ArgumentList @("/qn", "/norestart", "/i", "$env:systemdrive\puppet-agent-6.28.0-x64.msi") -Wait
Write-Host ('{0} :: Puppet installed :: {1}' -f $($MyInvocation.MyCommand.Name), $puppet)
if (-Not (Test-Path "C:\Program Files\Puppet Labs\Puppet\bin")) {
    Write-Host "Did not install puppet"
    exit 1
}
$env:PATH += ";C:\Program Files\Puppet Labs\Puppet\bin"

pause

## Set registry options
If (!( test-path "HKLM:\SOFTWARE\Mozilla\ronin_puppet")) {
    Write-host "Creating HKLM:\SOFTWARE\Mozilla\ronin_puppet"
    New-Item -Path HKLM:\SOFTWARE -Name Mozilla -force
    New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet -force
}

pause

Write-host "Setting HKLM:\SOFTWARE\Mozilla\ronin_puppet values"
New-Item -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name source -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'image_provisioner' -Value $image_provisioner -PropertyType String  -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'worker_pool_id' -Value $worker_pool_id -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'role' -Value $base_image -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'inmutable' -Value 'false' -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'last_run_exit' -Value '0' -PropertyType Dword -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'setup' -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Organisation' -Value $src_Organisation -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Repository' -Value $src_Repository -PropertyType String -force
New-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'Branch' -Value $src_Branch -PropertyType String -force

pause

## Clone ronin puppet locally to C:\ronin
Start-Process "$env:programfiles\git\bin\git.exe" -ArgumentList @(
    "clone",
    "https://github.com/$src_Organisation/$src_Repository",
    "$env:systemdrive\ronin"
) -Wait -NoNewWindow

Set-Location "$env:systemdrive\ronin"

pause

Start-Process "$env:programfiles\git\bin\git.exe" -ArgumentList @(
    "checkout",
    $src_branch
) -Wait -NoNewWindow

Start-Process "$env:programfiles\git\bin\git.exe" -ArgumentList @(
    "pull"
) -Wait -NoNewWindow

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

Get-ChildItem -Path $env:systemdrive\logs\*.log -Recurse | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue
Get-ChildItem -Path $env:systemdrive\logs\*.json -Recurse | Move-Item -Destination $env:systemdrive\logs\old -ErrorAction SilentlyContinue

Start-Process -FilePath "$env:programfiles\Puppet Labs\Puppet\bin\puppet.bat" -ArgumentList @(
    "apply",
    "manifests\nodes.pp",
    "--onetime",
    "--verbose",
    "--no-daemonize",
    "--no-usecacheonfailure",
    "--detailed-exitcodes",
    "--no-splay",
    "--show_diff",
    "--modulepath=modules`;r10k_modules",
    "--hiera_config=hiera.yaml",
    "--logdest $env:systemdrive\logs\$(get-date -format yyyyMMdd-HHmm)-bootstrap-puppet.log,$env:systemdrive\logs\$(get-date -format yyyyMMdd-HHmm)-bootstrap-puppet.json"
) -Wait -NoNewWindow

#puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=hiera.yaml --logdest $env:systemdrive\logs\$(get-date -format yyyyMMdd-HHmm)-bootstrap-puppet.log,$env:systemdrive\logs\$(get-date -format yyyyMMdd-HHmm)-bootstrap-puppet.json
[int]$puppet_exit = $LastExitCode
$puppet_exit

pause