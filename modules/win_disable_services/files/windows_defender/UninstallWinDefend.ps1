$status = (Get-MpComputerStatus)
if ($status -ne $null) {
	Uninstall-WindowsFeature -Name Windows-Defender
}
