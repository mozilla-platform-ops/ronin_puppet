write-host New-PSDrive -Name Z -PSProvider FileSystem -Root $sharePath -Credential $cred -Persist
