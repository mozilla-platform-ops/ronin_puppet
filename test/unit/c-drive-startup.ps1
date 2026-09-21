$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../../modules/win_scheduled_tasks/files/azure-maintainsystem.ps1"
function Write-Log { param($message, $severity) }
foreach ($size in @('Standard_F8alds_v7', 'Standard_F8ads_v7', 'Standard_D32ads_v7')) {
    if (-not (Test-AzureNvmeTemporaryDriveRequired -vmSize $size)) {
        throw "Existing D: requirement lost for $size"
    }
    if (Test-AzureNvmeTemporaryDriveRequired -vmSize $size -TaskDrive 'C:') {
        throw "C: workers must not require D: for $size"
    }
    Ensure-AzureNvmeTemporaryDrive -vmSize $size -TaskDrive 'C:' -scriptPath '/missing-disk-setup.ps1'
}
if (Test-AzureNvmeTemporaryDriveRequired -vmSize 'Standard_E8ads_v5') {
    throw 'E8ads v5 must not require NVMe setup'
}
Write-Output 'PASS: C: startup works without a temporary disk; existing D: requirements remain.'
