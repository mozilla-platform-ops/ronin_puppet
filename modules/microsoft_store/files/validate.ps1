$check = Get-AppxPackage | Where-Object {$psitem.name -eq "Microsoft.AV1VideoExtension"}

if (-not ([string]::IsNullOrEmpty($check))) {
    exit 0
}
else {
    exit 1
}