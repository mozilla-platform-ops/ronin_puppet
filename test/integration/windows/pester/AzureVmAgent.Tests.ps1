#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

BeforeDiscovery { . "$PSScriptRoot/Settings.ps1" }

Describe 'AzureVmAgent' -Tag IntegrationTests {
    BeforeAll {
        . "$PSScriptRoot/Settings.ps1"
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    It 'has the configured Azure VM Agent' {
        $agent = $Software | Where-Object DisplayName -Like 'Windows Azure VM Agent*' | Select-Object -First 1
        $agent.DisplayVersion | Should-BeString ((Get-ExpectedValue azure, vm_agent, version).Split('_')[0])
    }
}
