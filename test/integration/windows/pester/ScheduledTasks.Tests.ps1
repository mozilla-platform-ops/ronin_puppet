#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Scheduled tasks' -Tag IntegrationTests {
    Context 'Worker maintenance' {
        BeforeDiscovery {
            $tasks = @(
                @{ Name = 'disable_wu'; Script = 'disable_wu_task.ps1' }
                @{ Name = 'at_task_user_logon'; Script = 'at_task_user_logon.ps1' }
                @{ Name = 'maintain_system'; Script = 'maintainsystem.ps1' }
            )
            if ($Tester) { $tasks += @{ Name = 'kill_remote_clipboard'; Script = 'kill_local_clipboard.ps1' } }
        }

        It 'runs <Name> as SYSTEM' -ForEach $tasks {
            $task = Get-ScheduledTask -TaskName $Name | Select-Object -First 1
            $task.Settings.Enabled | Should-BeTrue
            $task.Principal.UserId | Should-BeString 'SYSTEM'
            $action = $task.Actions | Select-Object -First 1
            $action.Execute | Should-MatchString 'powershell\.exe$'
            $action.Arguments | Should-MatchString ([regex]::Escape("$Ronin\$Script"))
        }
        if ($Tester) {
            It 'runs the <Name> script' -ForEach @(
                @{ Name = 'xperf_kernel_trace_start'; Script = 'xperf_kernel_start.ps1' }
                @{ Name = 'xperf_kernel_trace_stop'; Script = 'xperf_kernel_stop.ps1' }
            ) {
                $action = (Get-ScheduledTask -TaskName $Name | Select-Object -First 1).Actions | Select-Object -First 1
                $action.Execute | Should-MatchString 'powershell\.exe$'
                $action.Arguments | Should-MatchString ([regex]::Escape("$Ronin\$Script"))
            }
        }
    }
}
