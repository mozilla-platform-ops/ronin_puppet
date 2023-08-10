git clone https://github.com/mozilla-platform-ops/worker-images.git C:\worker-images
Copy-Item C:\worker-images\scripts\windows\CustomFunctions\Bootstrap C:\Windows\System32\WindowsPowerShell\v1.0\Modules\ -Recurse
Import-Module Bootstrap -Force -PassThru
Set-PesterVersion
Invoke-RoninTest -Test C:\worker-images\tests\win\microsoft_tools.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\disable_services.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\error_reporting.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\suppress_dialog_boxes.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\files_system_management.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\firewall.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\network.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\ntp.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\power_management.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\virtual_drivers.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\logging.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\common_tools.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\git.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\mozilla_build.tests.ps1
Invoke-RoninTest -Test C:\worker-images\tests\win\mozilla_maintenance_service.tests.ps1
