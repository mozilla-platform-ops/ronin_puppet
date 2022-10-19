[environment]::setEnvironmentVariable("SCOOP", $env:SCOOP, "Machine")

Write-Output "Installing scoop to '$env:SCOOP'"

Invoke-Expression (New-Object System.Net.WebClient).DownloadString("https://get.scoop.sh")

$oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path
$shim_dir = "$env:SCOOP\shims"

Write-Output "Old global path: $oldpath"
$path_array = $oldpath -split ';'

if ($shim_dir -NotIn $path_array) {
  Write-Output "Adding '$shim_dir' to global PATH"
  Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value "$shim_dir;$oldpath"
}
