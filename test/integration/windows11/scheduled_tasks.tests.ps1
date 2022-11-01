Describe "Scheduled Tasks" {
    Context "Azure Maintain System" {
        BeforeAll {
            if (Test-Path "$ENV:ProgramData\PuppetLabs\ronin\maintainsystem.ps1") {
                [xml]$Script = Export-ScheduledTask -TaskName "maintain_system"
            }
        }
        It "Runs as system" {
            $Script.task.Principals.Principal.UserId | Should -Be "S-1-5-18"
        }
        It "Runs as highestavailable" {
            $Script.task.Principals.Principal.RunLevel | Should -Be "HighestAvailable"
        }
        It "Runs for 10 minutes" {
            $Script.task.Settings.IdleSettings.Duration | Should -Be "PT10M"
        }
        It "Wait Timeout is 1 hour" {
            $Script.task.Settings.IdleSettings.WaitTimeout | Should -Be "PT1H"
        }
        It "Task is pointing to Windows Powershell" {
            $Script.task.Actions.Exec.Command | Should -Be "C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
        }
        It "Arguments are correct" {
            $Script.task.Actions.Exec.Arguments | Should -Be "-executionpolicy bypass -File C:\ProgramData\PuppetLabs\ronin\maintainsystem.ps1"
        }
    }
}
