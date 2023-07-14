$worker_pool_id = 'win11-64-2009-hw-ref-alpha'
$base_image = 'win11642009hwrefalpha'
$src_Organisation = 'jwmoss'
$src_Repository = 'ronin_puppet'
$src_Branch = 'cloud_windows'
$image_provisioner = 'OSDCloud'

Start-Sleep -Seconds 120

## Setup logging and create c:\bootstrap
$null = New-Item -ItemType Directory -Force -Path "$env:systemdrive\BootStrap" -ErrorAction SilentlyContinue
Invoke-WebRequest "https://roninpuppetassets.blob.core.windows.net/binaries/prerequisites/nxlog-ce-2.10.2150.msi" -outfile "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" -UseBasicParsing
msiexec /i "$env:systemdrive\BootStrap\nxlog-ce-2.10.2150.msi" /passive
while (!(Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
Invoke-WebRequest  $ext_src/$nxlog_conf -outfile "$env:systemdrive\Program Files (x86)\nxlog\conf\$nxlog_conf" -UseBasicParsing
while (!(Test-Path "$env:systemdrive\Program Files (x86)\nxlog\")) { Start-Sleep 10 }
Invoke-WebRequest  $ext_src/$nxlog_pem -outfile "$env:systemdrive\Program Files (x86)\nxlog\cert\$nxlog_pem" -UseBasicParsing
Restart-Service -Name nxlog -force

## Download it
Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
Invoke-WebRequest https://raw.githubusercontent.com/$src_Organisation/$src_Repository/$src_branch/provisioners/windows/$image_provisioner/bootstrap.ps1 -OutFile "$env:systemdrive\BootStrap\bootstrap-src.ps1" -UseBasicParsing
Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\bootstrap.ps1
Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\bootstrap.ps1" /sc onstart /RL HIGHEST /f