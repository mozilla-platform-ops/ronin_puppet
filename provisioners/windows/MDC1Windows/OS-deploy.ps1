param(
    [string]$deployuser,
    [string]$deploymentaccess
)

## Mount Deployment share
## PSDrive is will unmount when the Powershell sessions ends. Ultimately maybe OK.
## net use will presist
$deploypw = ConvertTo-SecureString -String $deploymentaccess -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($deployuser, $deploypw)
#New-PSDrive -Name Z -PSProvider FileSystem -Root \\mdt2022.ad.mozilla.com\deployments  -Credential $credential -Persist

net use Z: \\mdt2022.ad.mozilla.com\deployments /user:$deployuser $deploymentaccess /persistent:yes

## Get node name
Import-Module "X:\Windows\System32\WindowsPowerShell\v1.0\Modules\DnsClient"
$Ethernet = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {$_.name -match "ethernet"}
$IPAddress = ($Ethernet.GetIPProperties().UnicastAddresses.Address | Where-object {$_.AddressFamily -eq "InterNetwork"}).IPAddressToString
$ResolvedName = (Resolve-DnsName -Name $IPAddress -Server "10.48.75.120").NameHost

Write-Host $IPAddress
Write-Host $ResolvedName
