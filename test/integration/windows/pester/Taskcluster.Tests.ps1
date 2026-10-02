#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Taskcluster' -Tag IntegrationTests {

    It 'owns runner.yml as SYSTEM' {
        (Get-Acl 'C:\worker-runner\runner.yml').GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
            Should-BeString 'S-1-5-18'
    }
    if (-not $Server25) {
        It 'has directory <_>' -ForEach @(
            'C:\Windows', 'C:\Program Files\Puppet Labs\Puppet', 'C:\generic-worker', 'C:\worker-runner'
        ) { Test-Path $_ -PathType Container | Should-BeTrue }
        It 'has NSSM' {
            Test-Path "C:\nssm\nssm-$(Get-ExpectedValue nssm, version)\win64\nssm.exe" | Should-BeTrue
        }
        It 'has the worker-runner service' { (Get-Service worker-runner).Name | Should-BeString 'worker-runner' }
        It 'has the configured version of <_>' -ForEach @(
            'C:\generic-worker\generic-worker.exe'
            'C:\worker-runner\start-worker.exe'
            'C:\generic-worker\taskcluster-proxy.exe'
            'C:\generic-worker\livelog.exe'
        ) {
            Test-Path $_ | Should-BeTrue
            $version = & $_ --short-version
            $LASTEXITCODE | Should-Be 0
            $version | Should-BeString (Get-ExpectedValue taskcluster, version)
        }
    }
}
