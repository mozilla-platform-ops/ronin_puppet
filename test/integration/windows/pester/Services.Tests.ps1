#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Services' -Tag IntegrationTests {
    Context 'Mozilla Maintenance Service' -Skip:(-not $Tester) {
        if (-not $Win10) {
            It 'has the service' { (Get-Service MozillaMaintenance).Name | Should-BeString 'MozillaMaintenance' }
        }
    }

    Context 'Windows services and NXLog' {
        BeforeDiscovery {
            $disabled = @('puppet', 'DiagTrack')
            if ($Tester) { $disabled += 'WSearch' }
        }

        It 'stops and disables <_>' -ForEach $disabled {
            $service = Get-CimInstance Win32_Service -Filter "Name='$_'"
            $service.State | Should-BeString 'Stopped'
            $service.StartMode | Should-BeString 'Disabled'
        }
        It 'runs NXLog' { (Get-CimInstance Win32_Service -Filter "Name='nxlog'").State | Should-BeString 'Running' }
    }

    Context 'Taskcluster' {
        if (-not $Server25) {
            It 'has the worker-runner service' { (Get-Service worker-runner).Name | Should-BeString 'worker-runner' }
        }
    }
}
