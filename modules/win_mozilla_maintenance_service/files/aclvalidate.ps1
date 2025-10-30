# specify folder
$folder = 'C:\Program Files (x86)\Mozilla Maintenance Service'

do {
    Start-Sleep -Seconds 5
}
while (-Not (Test-Path -Path $folder))

# set the new ACL object
$acl = Get-Acl $folder

$everyone = $acl.Access | Where-Object {$PSItem.IdentityReference -eq "Everyone"}

foreach ($access in $everyone) {
    if ($access.IdentityReference -eq "Everyone" -and
        $access.FileSystemRights -eq "FullControl" -and
        $access.InheritanceFlags -eq "ContainerInherit, ObjectInherit" -and
        $access.AccessControlType -eq "Allow") {
        Write-host "Permission set on $folder"
        exit 0
    }
    else {
        Write-host "Permissions not set on $folder"
        exit 1
    }
}
