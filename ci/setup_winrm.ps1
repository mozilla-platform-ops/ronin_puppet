Set-NetConnectionProfile -NetworkCategory Private
Enable-PSRemoting -Force -SkipNetworkProfileCheck

Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 512
Set-Item WSMan:\localhost\MaxTimeoutms -Value 1800000
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\Auth\Negotiate -Value $false
Set-Item WSMan:\localhost\Shell\MaxShellsPerUser -Value 100
Set-Item WSMan:\localhost\Shell\MaxProcessesPerShell -Value 100
Set-Item WSMan:\localhost\Shell\MaxConcurrentUsers -Value 100

Restart-Service WinRM
