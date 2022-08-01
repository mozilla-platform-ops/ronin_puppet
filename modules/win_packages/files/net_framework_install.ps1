# Windows update service needs to be running to enable net framework
# And it needs to be disabled before tasks are run.

Set-Service -name wuauserv -StartupType Manual
Start-Service -name wuauserv

Install-WindowsFeature NET-Framework-Features

Stop-Service -name wuauserv
Set-Service -name wuauserv -StartupType Disabled
