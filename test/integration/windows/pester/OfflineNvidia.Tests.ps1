#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Offline NVIDIA installation' -Tag IntegrationTests {
    Context 'GPU and audio drivers' {
        if ($Win25) {
            It 'uses a cached NVIDIA installer without network access' {
                # Keep Puppet's Facter overrides in a child process, as in the old test.
                & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PSScriptRoot/OfflineNvidia.ps1"
                $LASTEXITCODE | Should-Be 0
            }
        }
    }
}
