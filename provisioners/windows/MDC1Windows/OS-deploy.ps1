param(
    [string]$deployuser,
    [string]$deploymentaccess
)

$deploypw = ConvertTo-SecureString -String $deploymentaccess -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($deployuser, $deploypw)
#New-PSDrive -Name Z -PSProvider FileSystem -Root \\mdt2022.ad.mozilla.com\deployments  -Credential $credential -Persist

net use Z: \\mdt2022.ad.mozilla.com\deployments /user:$deployuser $deploymentaccess /persistent:yes
