# specify folder
$folder = 'C:\Program Files (x86)\Mozilla Maintenance Service'

# set the new ACL object
$acl = Get-Acl $folder

foreach ($access in $acl.Access) {
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
