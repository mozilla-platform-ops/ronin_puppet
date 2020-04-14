$DhcpDomain = ((Get-ItemProperty 'HKLM:SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters').'DhcpDomain')
$NVDomain = ((Get-ItemProperty 'HKLM:SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters').'NV Domain')

if ($NVDomain -like "*bitbar*") {
  $location = "bitbar"
  $mozspace = "bitbar"
} elseif ($DhcpDomain -like "*ec2*") {
	$location = "aws"
} elseif ($DhcpDomain -like "*cloudapp.net") {
    $location = "azure"
} elseif ($NVDomain -like "*microsoft*") {
    $location = "azure"
} else {
	$location = "datacenter"
}

if ($location -eq "datacenter") {
	if ($DhcpDomain -like "*MDC1*") {
		$mozspace = "mdc1"
	} elseif ($DhcpDomain -like "*MDC2*") {
		$mozspace = "mdc2"
	} elseif ($DhcpDomain -like "*MTV2*") {
		$mozspace = "mtv2"
	} else {
		$mozspace = "unkown"
	}
}

Write-host "custom_win_location=$location"
Write-host "custom_win_mozspace=$mozspace"
