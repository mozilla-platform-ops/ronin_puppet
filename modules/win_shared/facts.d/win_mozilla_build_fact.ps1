$mozbld_file = "$env:systemdrive\mozilla-build\VERSION"
if (Test-Path $mozbld_file) {
	$mozbld_ver = (get-content $mozbld_file)
} else {
	$mozbld_ver = 0.0
}

write-host "mozbld_ver=$mozbld_ver"
