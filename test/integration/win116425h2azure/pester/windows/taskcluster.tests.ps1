Describe "Taskcluster" {
    Context "Directories" {
        It "Generic Worker directory exists" {
            Test-Path "C:\generic-worker" | Should -Be $true
        }
        It "Worker Runner directory exists" {
            Test-Path "C:\worker-runner" | Should -Be $true
        }
    }
    Context "Generic Worker" {
        It "generic-worker.exe exists" {
            Test-Path "C:\generic-worker\generic-worker.exe" | Should -Be $true
        }
    }
    Context "Worker Runner" {
        It "start-worker.exe exists" {
            Test-Path "C:\worker-runner\start-worker.exe" | Should -Be $true
        }
        It "worker-runner Windows service exists" {
            Get-Service "worker-runner" | Should -Not -Be $null
        }
    }
    Context "Proxy" {
        It "taskcluster-proxy.exe exists" {
            Test-Path "C:\generic-worker\taskcluster-proxy.exe" | Should -Be $true
        }
    }
    Context "Livelog" {
        It "livelog.exe exists" {
            Test-Path "C:\generic-worker\livelog.exe" | Should -Be $true
        }
    }
}
