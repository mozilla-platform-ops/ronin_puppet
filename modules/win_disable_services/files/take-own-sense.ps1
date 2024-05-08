## Give administrator group owner access to Sense
## This allows the reg value to be updated

Add-Type -AssemblyName System.Security

$serviceName = "Sense"
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"

$acl = Get-Acl -Path $registryPath

$adminGroup = New-Object System.Security.Principal.NTAccount("Administrators")
$acl.SetOwner($adminGroup)

Set-Acl -Path $registryPath -AclObject $acl
