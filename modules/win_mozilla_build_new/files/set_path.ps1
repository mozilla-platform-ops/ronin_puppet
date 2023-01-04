## Windows native find conflicts with Msys2 find command
## To work around place Msys2 ahead of system 32 in system PATH
##  https://bugzilla.mozilla.org/show_bug.cgi?id=1806073#c9
## TODO: Pass the Msys dir value from the manifest to the script


$find_loc = (which find)
$ping_loc = (which ping)

if ($find_loc -like "*system32*") {
$msys_bin = "C:\mozilla-build\msys2\usr\bin"
$sys32 = "C:\Windows\system32"

write-host UPDATING

$current_path = (((Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).path).replace(";$msys_bin",""))
$new_path = ($current_path.replace("$sys32", "$msys_bin;$sys32"))


Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $new_path
	$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

$find_loc = (which find)
$ping_loc = (which ping)

if (($find_loc -like "*bin*") -and ($ping_loc -like "*system32*")) {
	exit 0
} else {
	exit 99
}
