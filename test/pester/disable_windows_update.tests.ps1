Describe "Disable Windows Update" {
    Context "Windows Update" {
        BeforeAll {
            $win_update_key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
            $win_au_key = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            $win_update_preview_builds = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PreviewBuilds"
            $service_key = "HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv"
        }
        It "Windows Update is disabled" {
            (Get-Service "wuauserv").StartType | Should -Be "Disabled"
        }
        It "Update Orchestrator Service is disabled" {
            (Get-Service "usosvc").StartType | Should -Be "Disabled"
        }
        It "Windows Update Medic Service is disabled" {
            (Get-Service "WaaSMedicSvc").StartType | Should -Be "Disabled"
        }
        It "Windows Update SearchOrderConfig is 0" {
            Get-ItemPropertyValue HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching -Name "SearchOrderConfig" | Should -Be 0
        }
        It "Windows Update AUOptions is 1" {
            Get-ItemPropertyValue $win_au_key -Name "AUOptions" | Should -Be 1
        }
        It "Windows Update NoAutoUpdate is 1" {
            Get-ItemPropertyValue $win_au_key -Name "NoAutoUpdate" | Should -Be 1
        }
        It "wuauserv start set to disable" {
            Get-ItemPropertyValue $service_key -Name "Start" | Should -Be 4
        }
    }
}
