$vms = Get-AzResource -ResourceType "Microsoft.Compute/virtualMachines"

$timer = [Diagnostics.Stopwatch]::StartNew()
$status = $vms | Foreach-object -Parallel {
    write-host "Processing $($_.name)"
    (get-azvm -name $_.name -status -ErrorAction SilentlyContinue)
}

$vms_running = $status | Where-Object {$PSItem.PowerState -match "VM Running"}

foreach ($vm in $vms_running) {
    $status = (get-azvm -name $vm.name -status -ErrorAction SilentlyContinue)
    if ($status.powerstate -like "*VM running*") {
        $out = (Invoke-AzVMRunCommand -ResourceGroupName $vm.ResourceGroupName -Name $vm.name -CommandId 'RunPowerShellScript' -ScriptPath "license_check.ps1")
        [PSCustomobject]@{
            VM = $VM.Name
            LicenseStatus = $out.Value.message
            IsLicensed = if ($out.Value.message -eq 1) {$true} else {$false}
        }
    }
}

$timer.stop()
Write-output "{0} hours, {1} minutes" -f $timer.Elapsed.hours,$timer.Elapsed.minutes