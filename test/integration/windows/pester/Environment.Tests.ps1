#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Environment' -Tag IntegrationTests {
    Context 'MozillaBuild and caches' {
        It 'sets TOOLTOOL_CACHE' {
            [Environment]::GetEnvironmentVariable('TOOLTOOL_CACHE', 'Machine') | Should-BeString 'C:\builds\tooltool_cache'
        }
        It 'uses a local Mercurial cache' {
            [Environment]::GetEnvironmentVariable('HG_CACHE', 'Machine') | Should-MatchString '^[CD]:\\hg-cache$'
        }
        It 'does not configure the removed pip download cache' {
            Get-Content 'C:\ProgramData\pip\pip.ini' -Raw | Should-NotMatchString '(?im)^download-cache\s*='
            [string][Environment]::GetEnvironmentVariable('PIP_DOWNLOAD_CACHE', 'Machine') | Should-BeEmptyString
        }
    }
}
