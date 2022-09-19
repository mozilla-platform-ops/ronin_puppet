$lic = Get-CimInstance -ClassName SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -ne $null }
$lic.LicenseStatus