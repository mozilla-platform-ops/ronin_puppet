Describe "Disabled Services" {
    Context "Windows Search" {
        It "is stopped" {
            (Get-Service "wsearch").Status | Should -Be "Stopped"
        }
    }
    Context "Puppet" {
        It "is stopped" {
            (Get-Service "puppet").Status | Should -Be "Stopped"
        }
    }
    Context "Windows Update" {
        It "wuauserv is disabled" {
            (Get-Service "wuauserv").StartType | Should -Be "Disabled"
        }
        It "Update Orchestrator is disabled" {
            (Get-Service "usosvc").StartType | Should -Be "Disabled"
        }
        It "Windows Update Medic is disabled" {
            (Get-Service "WaaSMedicSvc").StartType | Should -Be "Disabled"
        }
        It "SearchOrderConfig is 0" {
            Get-ItemPropertyValue HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching -Name "SearchOrderConfig" | Should -Be 0
        }
        It "AUOptions is 1" {
            Get-ItemPropertyValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" | Should -Be 1
        }
        It "NoAutoUpdate is 1" {
            Get-ItemPropertyValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" | Should -Be 1
        }
    }
    Context "UAC" {
        It "is enabled" {
            Get-ItemPropertyValue HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name "EnableLUA" | Should -Be 1
        }
    }
    Context "Clipboard" {
        It "cbdhsvc is disabled" {
            Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc" -Name "Start" | Should -Be 4
        }
    }
}

Describe "OOBE" {
    It "HideEULAPage is 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "HideEULAPage" | Should -Be 1
    }
    It "SkipMachineOOBE is 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "SkipMachineOOBE" | Should -Be 1
    }
    It "SkipUserOOBE is 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "SkipUserOOBE" | Should -Be 1
    }
    It "ProtectYourPC is 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "ProtectYourPC" | Should -Be 1
    }
}

Describe "Error Reporting" {
    It "Error dump folder exists" {
        Test-Path "C:\error-dumps" | Should -Be $true
    }
    It "DumpFolder registry is set" {
        Get-ItemPropertyValue "HKLM:\Software\Microsoft\Windows\Windows Error Reporting" -Name "DumpFolder" | Should -Be "C:\error-dumps"
    }
    It "LocalDumps is enabled" {
        Get-ItemPropertyValue "HKLM:\Software\Microsoft\Windows\Windows Error Reporting" -Name "LocalDumps" | Should -Be 1
    }
    It "DontShowUI is set" {
        Get-ItemPropertyValue "HKLM:\Software\Microsoft\Windows\Windows Error Reporting" -Name "DontShowUI" | Should -Be 1
    }
}

Describe "Suppress Dialog Boxes" {
    It "NoNewAppAlert is set" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoNewAppAlert" | Should -Be 1
    }
    It "NewNetworkWindowOff exists" {
        Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" | Should -Be $true
    }
}

Describe "File System" {
    It "8.3 name creation disabled" {
        Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisable8dot3NameCreation" | Should -Be 1
    }
    It "Last access update disabled" {
        Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" | Should -Be 2147483649
    }
}

Describe "Firewall" {
    It "Network is private" {
        (Get-NetConnectionProfile).NetworkCategory | Should -Be "Private"
    }
    It "ICMP is allowed" {
        (Get-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)").Enabled | Should -BeTrue
    }
}

Describe "IPv6" {
    It "IPv6 is enabled on network adapter" {
        (Get-NetAdapterBinding -ComponentID ms_tcpip6).Enabled | Should -Contain $true
    }
}

Describe "NTP" {
    It "NTP server is time.windows.com" {
        ((Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer") -split ",")[0] | Should -Be "time.windows.com"
    }
    It "Timezone is UTC" {
        (Get-TimeZone).ID | Should -Be "UTC"
    }
}

Describe "Power Management" {
    It "High performance plan is active" {
        ((Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan) |
        Where-Object { $_.ElementName -eq "High performance" }).IsActive |
        Should -BeTrue
    }
}

Describe "Scheduled Tasks" {
    Context "maintain_system" {
        BeforeAll {
            [xml]$Script = Export-ScheduledTask -TaskName "maintain_system"
        }
        It "Runs as SYSTEM" {
            $Script.task.Principals.Principal.UserId | Should -Be "S-1-5-18"
        }
        It "Runs as HighestAvailable" {
            $Script.task.Principals.Principal.RunLevel | Should -Be "HighestAvailable"
        }
    }
}

Describe "Virtual Audio Cable" {
    It "is installed" {
        $vac = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Virtual Audio Cable*" }
        $vac | Should -Not -BeNullOrEmpty
    }
}
