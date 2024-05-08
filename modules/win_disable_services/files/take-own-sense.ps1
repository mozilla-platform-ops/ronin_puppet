# PowerShell Script to Take Ownership and Disable the "Sense" Service

# Ensure the script is running with administrative privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges. Please run as Administrator."
    exit
}

# Load necessary assemblies
Add-Type -AssemblyName System.Security

# Define the service name and registry key path
$serviceName = "Sense"
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"

# Fetch the current ACL of the registry key
$acl = Get-Acl -Path $registryPath

# Create an administrator identity and set as the new owner
$adminGroup = New-Object System.Security.Principal.NTAccount("Administrators")
$acl.SetOwner($adminGroup)

# Apply the new ACL to the registry key
Set-Acl -Path $registryPath -AclObject $acl

# Change the start type of the service to disabled
Set-ItemProperty -Path $registryPath -Name "Start" -Value 4

# Attempt to stop the service if it is currently running
try {
    Stop-Service -Name $serviceName -Force
    Write-Host "Sense service stopped successfully."
} catch {
    exit 99
}
