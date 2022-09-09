# Currently just looking for VMs that are older than 1 day or with no running agent
# just report not shutdown
# Commented out code is for future use if we want to expand the scope.

$work_dir=$args[0]
$current = (get-date -format g)
$vms = (get-azvm)
$question_vms = New-Object System.Collections.ArrayList
$new_vms = New-Object System.Collections.ArrayList
$failed = New-Object System.Collections.ArrayList
$no_agent = New-Object System.Collections.ArrayList
$shutdown = New-Object System.Collections.ArrayList

$current = ((Get-Date).ToUniversalTime())

 write-host $current `(UTC`)


foreach ($vm in $vms) {
    # write-host checking  $vm.name
    $status = (get-azvm -resourcegroup $vm.ResourceGroupName -name $vm.Name -status -ErrorAction:SilentlyContinue)

    if (!($status -like $null)) {
        if ($status.Statuses.count -gt 0) {
            $display_status = $status.Statuses[1].DisplayStatus
        } else {
            $display_status = $null
        }
    } else {
        $display_status = $null
    }

    if ($status -eq $null) {
        # Assuming VMs that are missing fields is being created at time of audit
        $new_vms.Add($vm.name) | Out-Null
    } elseif ( $display_status -like "VM running") {
        $how_many = $how_many + 1
        $provisioned_time = $status.Disks[0].Statuses[0].Time
        if ($status.VMAgent.Statuses.count -gt 0) {
            $agent_status = $status.VMAgent.Statuses[0].DisplayStatus
        } else {
            $agent_status = $null
        }
        $agent_status = $status.VMAgent.Statuses[0].DisplayStatus
        $up_time = (New-TimeSpan -Start $provisioned_time -end $current -ErrorAction:SilentlyContinue)
        $hrs = $up_time.hours
        $dys = $up_time.days
        $days = [int]$dys
        $hours = [int]$hrs
        $tags = (Get-AzResource -ResourceGroupName $vm.ResourceGroupName -Name $vm.name).Tags
        $worker_pool = $tags['worker-pool-id']

        if (([int]$hours -ge 3) -or ([int]$days -ge 1)) {
            $question_vms.Add($vm.name) | Out-Null
            write-output ('{0} in {1} up days {2} up hours {3} and the agent is {4} ' -f $vm.name, $vm.location, $up_time.days, $up_time.hours, $agent_status)
            write-output ('{0}:{1}:{2}' -f $vm.name, $vm.location, $worker_pool) | Out-File -FilePath ${work_dir}/questions.txt -append
        }
    } else {
            #
    }
}
