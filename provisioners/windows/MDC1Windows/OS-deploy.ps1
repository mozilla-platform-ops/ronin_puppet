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
$Ethernet = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {$_.name -match "ethernet"}
$IPAddress = ($Ethernet.GetIPProperties().UnicastAddresses.Address | Where-object {$_.AddressFamily -eq "InterNetwork"}).IPAddressToString
$NodeEntry = [System.Net.Dns]::GetHostEntry($IPAddress)
$NodeName = $NodeEntry.HostName

Write-Host $IPAddress
Write-Host $NodeName
