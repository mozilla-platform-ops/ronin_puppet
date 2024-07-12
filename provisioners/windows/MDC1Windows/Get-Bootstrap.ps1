Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

Invoke-WebRequest -Uri https://raw.githubusercontent.com/SRCOrganisation/SRCRepository/SRCBranch/provisioners/windows/ImageProvisioner/authorized_keys -OutFile C:\users\administrator\authorized_keys

$local_bootstrap = "C:\bootstrap\bootstrap.ps1"

Invoke-WebRequest -Uri https://raw.githubusercontent.com/SRCOrganisation/SRCRepository/SRCBranch/provisioners/windows/ImageProvisioner/bootstrap.ps1 -OutFile $local_bootstrap

powershell -file $local_bootstrap -worker_pool_id WorkerPoolId -role 1Role  -src_Organisation SRCOrganisation -src_Repository SRCRepository -src_Branch SRCBranch
