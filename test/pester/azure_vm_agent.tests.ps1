Describe "Windows Azure VM Agent" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $Software = Get-InstalledSoftware | Where-Object {
            $_.DisplayName -like "Windows Azure VM Agent*"
        }

        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $VmAgentVersionRaw = if ($variant.azure.vm_agent.version) { $variant.azure.vm_agent.version } else { $win.azure.vm_agent.version }

        $ExpectedSoftwareVersion = [Version]($VmAgentVersionRaw -split "_")[0]
    }

    It "Windows Azure VM Agent is installed" {
        $Software.DisplayName | Should -Not -Be $null
    }

    It "Windows Azure VM Agent major version" {
        ([Version]$Software.DisplayVersion).Major | Should -Be $ExpectedSoftwareVersion.Major
    }

    It "Windows Azure VM Agent minor version" {
        ([Version]$Software.DisplayVersion).Minor | Should -Be $ExpectedSoftwareVersion.Minor
    }

    It "Windows Azure VM Agent build version" {
        ([Version]$Software.DisplayVersion).Build | Should -Be $ExpectedSoftwareVersion.Build
    }

    It "Windows Azure VM Agent revision" {
        ([Version]$Software.DisplayVersion).Revision | Should -Be $ExpectedSoftwareVersion.Revision
    }
}
