Describe "Taskcluster" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $nssm = if ($variant.nssm.version) { $variant.nssm.version } else { $win.nssm.version }
        $taskclusterExpectedSoftwareVersion = if ($variant.taskcluster.version) { $variant.taskcluster.version } else { $win.taskcluster.version }
    }

    Context "Non-Sucking Service Manager" {
        It "NSSM is installed" {
            Test-Path "C:\nssm\nssm-$($nssm)\win64\nssm.exe" | Should -Be $true
        }

        It "worker-runner service exists" {
            Get-Service "worker-runner" | Should -Not -Be $null
        }
    }

    Context "Taskcluster directories" {
        It "C:\generic-worker exists" {
            Test-Path "C:\generic-worker" | Should -Be $true
        }

        It "C:\worker-runner exists" {
            Test-Path "C:\worker-runner" | Should -Be $true
        }
    }

    Context "Generic Worker" {
        It "generic-worker.exe exists" {
            Test-Path "C:\generic-worker\generic-worker.exe" | Should -Be $true
        }

        It "generic-worker version matches hiera" {
            Start-Process -FilePath "C:\generic-worker\generic-worker.exe" -ArgumentList "--short-version" -RedirectStandardOutput "Testdrive:\gwversion.txt" -Wait -NoNewWindow
            Get-Content "Testdrive:\gwversion.txt" | Should -Be $taskclusterExpectedSoftwareVersion
        }
    }

    Context "Worker Runner" {
        It "start-worker.exe exists" {
            Test-Path "C:\worker-runner\start-worker.exe" | Should -Be $true
        }

        It "start-worker version matches hiera" {
            Start-Process -FilePath "C:\worker-runner\start-worker.exe" -ArgumentList "--short-version" -RedirectStandardOutput "Testdrive:\startworkerversion.txt" -Wait -NoNewWindow
            Get-Content "Testdrive:\startworkerversion.txt" | Should -Be $taskclusterExpectedSoftwareVersion
        }
    }

    Context "Proxy" {
        It "taskcluster-proxy.exe exists" {
            Test-Path "C:\generic-worker\taskcluster-proxy.exe" | Should -Be $true
        }

        It "proxy version matches hiera" {
            Start-Process -FilePath "C:\generic-worker\taskcluster-proxy.exe" -ArgumentList "--short-version" -RedirectStandardOutput "Testdrive:\proxyversion.txt" -Wait -NoNewWindow
            Get-Content "Testdrive:\proxyversion.txt" | Should -Be $taskclusterExpectedSoftwareVersion
        }
    }

    Context "Livelog" {
        It "livelog.exe exists" {
            Test-Path "C:\generic-worker\livelog.exe" | Should -Be $true
        }

        It "livelog version matches hiera" {
            Start-Process -FilePath "C:\generic-worker\livelog.exe" -ArgumentList "--short-version" -RedirectStandardOutput "Testdrive:\livelogversion.txt" -Wait -NoNewWindow
            Get-Content "Testdrive:\livelogversion.txt" | Should -Be $taskclusterExpectedSoftwareVersion
        }
    }
}
