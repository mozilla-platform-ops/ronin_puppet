function Get-InstanceData {
  param (
    [string] $instanceId = ((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/instance-id')),
    [string] $publicKeys = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/public-keys'),
	[string] $az = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/placement/availability-zone'),
	# commented out for testing
	#[string] $workerType = $(if ($publicKeys.StartsWith('0=mozilla-taskcluster-worker-')) { $publicKeys.Replace('0=mozilla-taskcluster-worker-', '') } else { (Invoke-WebRequest -Uri 'http://169.254.169.254/latest/user-data' -UseBasicParsing | ConvertFrom-Json).workerType })
	[string] $workerType = "gecko-t-win10-64-pup"
)

  process {
    Write-host "custom_win_instance_id=$instanceId"
	Write-host "custom_win_public_keys=$publicKeys"
	Write-host "custom_win_availability_zone=$az"
	Write-host "custom_win_workertype=$workerType"
  }

}
if ((Get-Service 'Ec2Config' -ErrorAction SilentlyContinue) -or (Get-Service 'AmazonSSMAgent' -ErrorAction SilentlyContinue)) {
	Get-InstanceData
} else {
	exit
}
