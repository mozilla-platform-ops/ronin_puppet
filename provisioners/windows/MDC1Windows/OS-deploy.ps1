param(
    [string]$deployuser,
    [string]$deploymentaccess
)

Set-Location X:\working
Import-Module "X:\Windows\System32\WindowsPowerShell\v1.0\Modules\DnsClient"
Import-Module "X:\Windows\System32\WindowsPowerShell\v1.0\Modules\powershell-yaml"
#Import-Module "X:\Windows\System32\WindowsPowerShell\v1.0\Modules\Storage"

# Get all partitions
$partitions = Get-Partition

# Check if there are no partitions
if ($partitions.Count -eq 0) {
    # Get available disk space if no partitions exist
    $availableSpace = Get-Disk | Where-Object { $_.OperationalStatus -eq 'Online' } | Measure-Object -Property Size -Sum
    Write-Host "No partitions found. Available Disk Space: $($availableSpace.Sum / 1MB) MB"

    $local_files_size = 20480
    $all_space = $($availableSpace.Sum / 1MB)
    $primary_size = ($availableSpace.Sum - $local_files_size)

    Write-Host "Primary partition size is $($primary_size / 1MB) MB"

}
else {
    # Display information about each partition
    foreach ($partition in $partitions) {
        Write-Host "Partition $($partition.DriveLetter):"
        Write-Host "   File System: $($partition.FileSystem)"
        Write-Host "   Capacity: $($partition.Size / 1GB) GB"
        Write-Host "   Free Space: $($partition.SizeRemaining / 1GB) GB"
        Write-Host ""
    }
}

$diskPartScript = @'
    select disk 0
    create partition primary size=15000
    create partition primary
    select partition 1
    format quick fs=ntfs label="Partition1"
    assign letter=Y
    select partition 2
    format quick fs=ntfs label="Partition2"
    assign letter=C
    exit
'@

$diskPartScript | Out-File -FilePath "$env:TEMP\diskpart_script.txt" -Encoding ASCII
write-host Start-Process "diskpart.exe" -ArgumentList "/s $env:TEMP\diskpart_script.txt" -Wait


## Mount Deployment share
## PSDrive is will unmount when the Powershell sessions ends. Ultimately maybe OK.
## net use will presist
$deploypw = ConvertTo-SecureString -String $deploymentaccess -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($deployuser, $deploypw)
#New-PSDrive -Name Z -PSProvider FileSystem -Root \\mdt2022.ad.mozilla.com\deployments  -Credential $credential -Persist

net use Z: \\mdt2022.ad.mozilla.com\deployments /user:$deployuser $deploymentaccess /persistent:yes

## Get node name
#Import-Module "X:\Windows\System32\WindowsPowerShell\v1.0\Modules\DnsClient"

$Ethernet = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {$_.name -match "ethernet"}
$IPAddress = ($Ethernet.GetIPProperties().UnicastAddresses.Address | Where-object {$_.AddressFamily -eq "InterNetwork"}).IPAddressToString
$ResolvedName = (Resolve-DnsName -Name $IPAddress -Server "10.48.75.120").NameHost

$index = $ResolvedName.IndexOf('.')
$shortname = $ResolvedName.Substring(0, $index)

Write-Host $IPAddress
Write-Host $ResolvedName
Write-Host $shortname

## Get data
#Import-Module "X:\Windows\System32\WindowsPowerShell\v1.0\Modules\powershell-yaml"

# assumes files is in the same dir
$YAML = Convertfrom-Yaml (Get-Content "pools.yml" -raw)

foreach ($pool in $YAML.pools) {
    foreach ($node in $pool.nodes) {
        if ($node -eq $shortname) {
            $neededImage = $pool.image
            Write-Output "The associated image for $shortname is: $neededImage"
            $found = $true
            break
        }
        if ($found) {
            break
        } else {
            $defaultPool = $YAML.pools | Where-Object { $_.name -eq "Default" }
            $neededImage = $defaultPool.image
            Write-Output = "Node not found. defualting"
            Write-Output "The image for the 'Default' pool is: $neededImage"
        }
    }
}

## It seems like the Z: drive needs to be access before script exits to presists
dir Z:\

$setup = "Z:\Images\" + $neededImage + "\setup.exe"
$setup
