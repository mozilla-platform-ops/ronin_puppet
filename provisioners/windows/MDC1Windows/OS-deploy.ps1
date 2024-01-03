param(
    [string]$deployuser,
    [string]$deploymentaccess
)

$deploymentaccess = ConvertTo-SecureString -String $deploymentaccess -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($deployuser, $deploymentaccess)
New-PSDrive -Name Z -PSProvider FileSystem -Root //mdt2022.ad.mozilla.com/deployments  -Credential -Credential $credential -Persist
