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
    Write-Host "No partitions found."

    $local_files_size = 21480
    $all_space = [math]::Floor($availableSpace.Sum / 1MB)
    $primary_size = ($all_space - $local_files_size)

    Write-Host "Avilable space $all_space MB"
    Write-Host "Primary partition size is $primary_size MB"
    Write-Host "Local Install Partition is $local_files_size MB"

    $diskPartScript = @"
        select disk 0
        clean
        convert gpt
        create partition efi size=100
        format fs=fat32 label=EFI
        assign letter=S
        create partition msr size=16
        create partition primary size=$primary_size
        format fs=ntfs quick
        assign letter=C
        create partition primary size=20480
        format fs=ntfs quick
        assign letter=Y
        exit
"@

    $diskPartScript | Out-File -FilePath "$env:TEMP\diskpart_script.txt" -Encoding ASCII
    Start-Process "diskpart.exe" -ArgumentList "/s $env:TEMP\diskpart_script.txt" -Wait
}
else {
    $part1 = Get-Partition -PartitionNumber 3
    $part2 = Get-Partition -PartitionNumber 4

    if ($part1.DriveLetter -ne 'C') {
        write-host OS disk is wrong
    }
    if ($part2.DriveLetter -ne 'Y') {
        Set-Partition -DriveLetter $part2.DriveLetter -NewDriveLetter Y
        Write-Host Relabeling partition 2 to Y
    }
    foreach ($partition in $partitions) {
        Write-Host "Partition $($partition.DriveLetter):"
        Write-Host "   File System: $($partition.FileSystem)"
        Write-Host "   Capacity: $($partition.Size / 1GB) GB"
        Write-Host "   Free Space: $($partition.SizeRemaining / 1GB) GB"
        Write-Host ""
    }
}

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
    $WorkerPool = $pool.name
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

$source_install = "Z:\Images\" + $neededImage
$local_install = "Y:\"
$OS_files = $local_install + $neededImage
$setup = $local_install + $neededImage + "\setup.exe"
$secret_dir = $local_instal + "secrets"
$secret_file = $secret_dir + "\vault.yaml"
$source_secrets = "Z:\secrets\" + $WorkerPool + ".yaml"

if (!(Test-Path $setup)) {
    Write-Host Install files wrong or missing
    Write-Host Will resync
    if ((Get-ChildItem -Path $local_install -Force).Count -gt 0) {
        Write-Host Wrong install files - REMOVING
        Remove-Item -Path "${local_install}*" -Recurse -Force
    }
    ## Mount Deployment share
    ## PSDrive is will unmount when the Powershell sessions ends. Ultimately maybe OK.
    ## net use will presist
    $deploypw = ConvertTo-SecureString -String $deploymentaccess -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($deployuser, $deploypw)
    #New-PSDrive -Name Z -PSProvider FileSystem -Root \\mdt2022.ad.mozilla.com\deployments  -Credential $credential -Persist

    $maxRetries = 20
    $retryInterval = 30

    Write-Host Mounting Deployment Share
    for ($retryCount = 1; $retryCount -le $maxRetries; $retryCount++) {
        try {
            net use Z: \\mdt2022.ad.mozilla.com\deployments /user:$deployuser $deploymentaccess /persistent:yes
            break
        }
        catch {
            Write-Host Unable to mount Deployment Share
            Start-Sleep -Seconds $retryInterval
        }
    }
    if ($retryCount -gt $maxRetries) {
        Write-Host Failed to mount Deployment Share
        exit 99
    }

    dir Z:\

    write-host Copy-Item -Path $source_install -Destination $local_install -Recurse -Force
    write-host New-Item -ItemType Directory $secret_dir
    write-host Copy-Item -Path $source_secrets -Destination $secret_file -Force


    Write-Host Disconecting Deployment Share
    net use Z: /delete
}

dir $local_install
Set-Location -Path $OS_files
write-host Start-Process -FilePath $setup -ArgumentList "/unattend:autounattend.xml"
#Start-Process -FilePath $setup -ArgumentList "/unattend:autounattend.xml"
write-host cmd /c $setup /unattend:autounattend.xml /imageindex 5
