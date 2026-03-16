Describe "Common Tools" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $gpg4win = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -like "Gpg4win (2.3.0)"
        }
        $7zip = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -match "Zip"
        }
        $sublimetext = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -match "Sublime Text*"
        }
    }
    Context "gpg4win" {
        It "GPG4Win is installed" {
            $gpg4win.DisplayName | Should -Not -Be $null
        }

        It "GPG4Win Version is 2.3.0" {
            $gpg4win.DisplayVersion | Should -Be "2.3.0"
        }

        It "GPG4Win directory exists" {
            Test-Path "${ENV:ProgramFiles(x86)}\GNU\GnuPG\bin\kleopatra.exe" | Should -BeTrue
        }
    }
    Context "7-Zip" {
        It "7-Zip is installed" {
            $7zip.DisplayName | Should -Not -Be $null
        }

        It "7-Zip Version is 18.06.00.0" {
            $7zip.DisplayVersion | Should -Be "18.06.00.0"
        }
    }
    Context "Sublime Text" -Skip {
        It "Sublime Text is installed" {
            $sublimetext.DisplayName | Should -Not -Be $null
        }
        It "Binary exists" {
            Test-Path "$ENV:ProgramFiles\Sublime Text 3\subl.exe" | Should -BeTrue
        }
    }
}
