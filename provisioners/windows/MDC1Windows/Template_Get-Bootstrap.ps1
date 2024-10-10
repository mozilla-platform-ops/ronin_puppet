<<<<<<< HEAD
=======
function Set-PXE {
    Import-Module Microsoft.Windows.Bcd.Cmdlets
    $data = (Get-BcdStore).entries | ForEach-Object {
        $d = ($_.Elements | Where-Object { $_.Name -eq "Description" }).value
        if ($d -match "IPv4") {
            $PSItem
        }
    }
    bcdedit /set "{fwbootmgr}" BOOTSEQUENCE "{$($data.Identifier.Guid)}"
    Restart-Computer -Force
}

## Set up ssh early on to ensure access if bootstrap fails.
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

$destinationDirectory = "C:\users\administrator\.ssh"
$authorized_keys =  $destinationDirectory + "authorized_keys"
$chocoPath = 'C:\ProgramData\Chocolatey\bin'

## Install chocolatey here
Set-ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

if (-Not (Test-Path "$chocoPath\choco.exe")) {
    Set-PXE
}

New-Item -ItemType Directory -Path $destinationDirectory -Force

Invoke-WebRequest -Uri https://raw.githubusercontent.com/SRCOrganisation/SRCRepository/SRCBranch/provisioners/windows/ImageProvisioner/ssh/authorized_keys -OutFile C:\users\administrator\.ssh\authorized_keys
Invoke-WebRequest -Uri https://raw.githubusercontent.com/SRCOrganisation/SRCRepository/SRCBranch/provisioners/windows/ImageProvisioner/ssh/sshd_config -OutFile C:\programdata\ssh\sshd_config

New-NetFirewallRule -Name "AllowSSH" -DisplayName "Allow SSH" -Description "Allow SSH traffic on port 22" -Profile Any -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22

Start-Service sshd

Set-Service -Name sshd -StartupType Automatic

>>>>>>> 619c23f53994f6093d2e5e8873e166ef68d56b05
$local_bootstrap = "C:\bootstrap\bootstrap.ps1"

Invoke-WebRequest -Uri https://raw.githubusercontent.com/SRCOrganisation/SRCRepository/SRCBranch/provisioners/windows/ImageProvisioner/bootstrap.ps1 -OutFile $local_bootstrap

<<<<<<< HEAD
D:\applications\psexec.exe -i -s -d -accepteula powershell.exe -ExecutionPolicy Bypass -file $local_bootstrap -worker_pool_id "WorkerPoolId" -role "1Role"  -src_Organisation "SRCOrganisation" -src_Repository "SRCRepository" -src_Branch "SRCBranch" -hash "1HASH" -secret_date "1secret_date" -puppet_version "1puppet_version"
=======
D:\applications\psexec.exe -i -s -d -accepteula powershell.exe -ExecutionPolicy Bypass -file $local_bootstrap -worker_pool_id "WorkerPoolId" -role "1Role"  -src_Organisation "SRCOrganisation" -src_Repository "SRCRepository" -src_Branch "SRCBranch" -hash "1HASH" -secret_date "1secret_date" -puppet_version "1puppet_version"
>>>>>>> 619c23f53994f6093d2e5e8873e166ef68d56b05
