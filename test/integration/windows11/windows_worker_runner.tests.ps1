Describe "Windows Worker Runner" {
    BeforeAll {
        $worker_runner_service = Get-Service "worker-runner"
    }
    It "Custom NSSM exists" {
        Test-Path "C:\nssm\nssm-2.24\win64\nssm.exe" | Should -Be $true
    }
    It "Windows Service Exists" {
        $worker_runner_service | Should -Not -Be $null
    }
    It "Worker runner directory exists" {
        Test-Path "C:\worker-runner" | Should -Be $true
    }
}