function Get-AzureInstanceMetadata {
  [CmdletBinding()]
  param (
    [String]
    $ApiVersion = '2025-04-07',
    [String]
    $Endpoint = 'instance',
    [String]
    $Query
  )

  $uri = switch ($Query) {
    "tags" {
      ("http://169.254.169.254/metadata/{0}/{1}/?api-version={2}" -f $Endpoint, "compute/tagsList", $ApiVersion)
    }
    "compute" {
      ("http://169.254.169.254/metadata/{0}/{1}?api-version={2}" -f $Endpoint, "compute", $ApiVersion)
    }
    Default {
      ("http://169.254.169.254/metadata/{0}?api-version={1}" -f $Endpoint, $ApiVersion)
    }
  }

  $splat = @{
    Headers = @{Metadata = "true" }
    Method  = "Get"
    URI     = $uri
  }

  Invoke-RestMethod @splat
}

$DhcpDomain = ((Get-ItemProperty 'HKLM:SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters').'DhcpDomain')
$NVDomain = ((Get-ItemProperty 'HKLM:SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters').'NV Domain')

switch -Wildcard ($DhcpDomain) {
  "*microsoft*" {
    $location = "azure"
  }
  "*cloudapp.net*" {
    $location = "azure"
  }
  Default {
    $location = $null
  }
}

if ($location -eq "azure") {
  $metaData = Get-AzureInstanceMetadata
  $vmSize = $metaData.compute.vmSize
} 
else {
  $vmsize = ""
}
write-host "custom_win_vmSize=$vmsize"