$credential = New-Object System.Management.Automation.PSCredential($env:deployuser, $env:deploymentaccess)
New-PSDrive -Name Z -PSProvider FileSystem -Root //mdt2022.ad.mozilla.com/deployments  -Credential -Credential $credential -Persist
