## How to Setup OSDCloud

### Steps

1. Install Windows ADK and Windows PE Add-on from [Microsoft](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
2. Launch Windows Powershell and install OSDCloud. More information [here](https://www.osdcloud.com/osdcloud/setup).
3. Run `New-OSDCloudTemplate`, which will populate `C:\ProgramData\OSDCloud` and `C:\OSDCloud`
4. Create the following script that will be copied to the ISO that is used to create local vault to be used by powershell and puppet. Note: This contains secrets used by Puppet and Azure in plaintext.
```Powershell
## Variables
$DnsServer = "10.48.75.120"
$Azcopy_app_id = ""
$azcopy_app_client_secret = ""
$azcopy_tenant_id = ""
## Import dnsclient
Import-Module "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\DnsClient"
## Get the resolved dns name
$Ethernet = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {$_.name -match "ethernet"}
$IPAddress = ($Ethernet.GetIPProperties().UnicastAddresses.Address | Where-object {$_.AddressFamily -eq "InterNetwork"}).IPAddressToString
$ResolvedName = (Resolve-DnsName -Name $IPAddress -Server $DnsServer).NameHost

## If the nuc resolves to a reference tester, set the taskcluster access token and winadm password
if ($ipaddress -like "10.49.64.*") {
    $win_adminpw = "foo"
    $taskcluster_access_token = "bar"
}
## If the nuc resolves to a performance tester, set the taskcluster access token and windows pw
else {
    $win_adminpw = "this"
    $taskcluster_access_token = "that" 
}

$vault_yaml = @"
---
win_adminpw: "$($win_adminpw)"
win_vncpw_hash: "foo"
win_readonly_vncpw_hash: "bar"
taskcluster_access_token: "$($taskcluster_access_token)"
tooltool_tok: ""
"@

if (-Not (Test-Path "C:\ProgramData")) {
    throw "Unable to find C:\ProgramData"
}

New-Item -Path "C:\ProgramData" -Name "secrets" -ItemType "Directory" -Force
New-Item -Path "C:\ProgramData\secrets" -Name "vault.yaml" -ItemType "File" -Value $vault_yaml

$azcopy_yaml = @"
---
azcopy_app_id: "$($Azcopy_app_id)"
azcopy_app_client_secret: "$($azcopy_app_client_secret)"
azcopy_tenant_id: "$($azcopy_tenant_id)"
"@

## Create the azcopy creds
New-Item -Path "C:\" -name "azcredentials.yaml" -ItemType "File" -Value $azcopy_yaml -Force
```
5. Create a powershell script called `vault.ps1` under `C:\OSDCloud\Config\Scripts\Shutdown` and take the contents from step 4 and paste them into that file.
6. Create a powershell script called `generateiso.ps1` wherever you want locally and take the contents below and populate it:
```Powershell
## bootstrap script hosted in this repository
$bootstrap = "https://raw.githubusercontent.com/mozilla-platform-ops/ronin_puppet/win11ref/provisioners/windows/OSDCloud/bootstrap_winreftester.ps1"
## local copy of OSDCloud where the script vault.ps1 will run
$workspace = "C:\OSDCloud"

$cloudwinpe = @{
    WorkspacePath = $workspace
    WebPSScript   = $bootstrap
}

Edit-OSDCloudWinPE @cloudwinpe
```
7. Run `generateiso.ps1` and browse to the root of the OSDCloud workspace, where you'll find an ISO called `OSDCloud_NoPrompt.iso`. This will be the ISO that is to be mounted onto the reference testers.