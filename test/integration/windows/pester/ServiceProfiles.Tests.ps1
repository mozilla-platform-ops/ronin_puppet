#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Services and scheduled tasks' -Tag IntegrationTests {
    BeforeAll {
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    BeforeDiscovery {
        $disabled = @('puppet', 'DiagTrack')
        if ($Tester) { $disabled += 'WSearch' }
        $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        $settings = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Value = '0' }
            @{ Path = "$wu\AU"; Name = 'AUOptions'; Value = '1' }
            @{ Path = "$wu\AU"; Name = 'NoAutoUpdate'; Value = '1' }
            @{ Path = $wu; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; Value = '1' }
            @{ Path = $wu; Name = 'DisableWindowsUpdateAccess'; Value = '1' }
        )
        foreach ($name in @('wuauserv', 'WaaSMedicSvc', 'DoSvc')) {
            $settings += @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"; Name = 'Start'; Value = '4' }
        }
        if ($Tester) {
            $settings += @(
                @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc'; Name = 'Start'; Value = '4' }
                @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc'; Name = 'UserServiceFlags'; Value = '0' }
                @{ Path = 'HKLM:\SOFTWARE\Microsoft\Clipboard'; Name = 'EnableClipboardHistory'; Value = '0' }
            )
        }
        $tasks = @(
            @{ Name = 'disable_wu'; Script = 'disable_wu_task.ps1' }
            @{ Name = 'at_task_user_logon'; Script = 'at_task_user_logon.ps1' }
            @{ Name = 'maintain_system'; Script = 'maintainsystem.ps1' }
        )
        if ($Tester) { $tasks += @{ Name = 'kill_remote_clipboard'; Script = 'kill_local_clipboard.ps1' } }
    }
    Context 'Disabled services' {
        It 'stops and disables <_>' -ForEach $disabled {
            $service = Get-CimInstance Win32_Service -Filter "Name='$_'"
            $service.State | Should-BeString 'Stopped'
            $service.StartMode | Should-BeString 'Disabled'
        }
    }

    Context 'Windows Update and clipboard policies' {
        It 'sets <Path>\<Name> to <Value>' -ForEach $settings {
            [string](Get-ItemPropertyValue $Path $Name) | Should-BeString $Value
        }
    }

    Context 'Scheduled tasks' {
        It 'runs <Name> as SYSTEM' -ForEach $tasks {
            $task = Get-ScheduledTask -TaskName $Name | Select-Object -First 1
            $task.Settings.Enabled | Should-BeTrue
            $task.Principal.UserId | Should-BeString 'SYSTEM'
            $action = $task.Actions | Select-Object -First 1
            $action.Execute | Should-MatchString 'powershell\.exe$'
            $action.Arguments | Should-MatchString ([regex]::Escape("$Ronin\$Script"))
        }
        if ($Tester) {
            It 'has <_>' -ForEach @('xperf_kernel_start.ps1', 'xperf_kernel_stop.ps1', 'xperf_register_tasks.ps1') {
                Test-Path "$Ronin\$_" | Should-BeTrue
            }
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

    Context 'Logging' {
        It 'has NXLog 2.10.2150' {
            ($Software | Where-Object DisplayName -EQ 'NXLog-CE' | Select-Object -First 1).DisplayVersion |
                Should-MatchString '^2\.10\.2150(?:\.\d+)?$'
        }
        It 'has the NXLog configuration and certificate bundle' {
            Test-Path 'C:\Program Files (x86)\nxlog\conf\nxlog.conf' | Should-BeTrue
            (Get-FileHash 'C:\Program Files (x86)\nxlog\cert\papertrail-bundle.pem' -Algorithm SHA256).Hash |
                Should-BeString 'AE31ECB3C6E9FF3154CB7A55F017090448F88482F0E94AC927C0C67A1F33B9CF'
        }
        It 'runs NXLog' { (Get-CimInstance Win32_Service -Filter "Name='nxlog'").State | Should-BeString 'Running' }
    }
}
