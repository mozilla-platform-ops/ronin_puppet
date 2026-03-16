Describe "Disable Services" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    Context "<_> service" -ForEach @(
        "wsearch",
        "puppet"
    ) {
        It "Exists as a service" {
            Get-Service $_ | Should -Not -Be $null
        }
        It "Windows Search is disabled" {
            (Get-Service $_).Status | Should -Be "Stopped"
        }
    }
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
    Context "Disable User Account Control" {
        It "UAC is enabled" {
            Get-ItemPropertyValue HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name "EnableLUA" | Should -Be 1
        }
    }
    Context "Disable Local Clipboard" -Tags "Azure" {
        #It "Service is stopped" {
        #    (Get-Service -Name "cbdhsvc*").Status | Should -Be "Stopped"
        #}
        It "cbdhsvc is set to disabled" {
            Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc" -Name "Start" | Should -Be 4
        }
        It "UserServiceFlags is set to 0" {
            Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc" -Name "UserServiceFlags" | Should -Be 0
        }
        It "ClipboardHistory is set to 0" {
            Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Clipboard" -Name "EnableClipboardHistory" | Should -Be 0
        }
    }
}
