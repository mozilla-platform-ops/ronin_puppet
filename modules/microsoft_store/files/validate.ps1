$check = Get-AppxPackage | Where-Object {$psitem.name -eq "Microsoft.AV1VideoExtension"}

if ($null -eq $check) {
    exit 0
}
else {
    exit 1
}
