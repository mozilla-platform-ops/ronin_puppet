# specify folder
$folder = 'C:\Program Files (x86)\Mozilla Maintenance Service'

do {
    Start-Sleep -Seconds 5
}
while (-Not (Test-Path -Path $folder))

# set the new ACL object
$acl = Get-Acl $folder

# setup AccessRule for Everyone with FullControl
$permission = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone","FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")

# add this AccessRule to the ACL
$acl.AddAccessRule($permission)

if (-Not (Test-Path $folder)) {
    Write-Host "Unable to find $folder"
    exit 1
}

# set the ACL of this item
Try {
    Set-Acl -Path $folder -AclObject $acl -ErrorAction "Stop"
    Write-host "Set path"
    Exit 0
}
Catch {
    Write-Host "Unable to set permissions on $folder"
    exit 1
}
