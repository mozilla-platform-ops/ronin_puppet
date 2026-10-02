#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'MozillaBuild and caches' -Tag IntegrationTests {

    It 'has directory <_>' -ForEach @('C:\mozilla-build', 'C:\builds\tooltool_cache') {
        Test-Path $_ -PathType Container | Should-BeTrue
    }
    It 'has file <_>' -ForEach @(
        'C:\mozilla-build\msys2\usr\bin\sh.exe'
        'C:\mozilla-build\python3\Lib\site-packages\certifi\cacert.pem'
        'C:\mozilla-build\python3\Lib\site-packages\psutil\__init__.py'
    ) { Test-Path $_ | Should-BeTrue }
    It 'has the configured MozillaBuild version' {
        (Get-Content 'C:\mozilla-build\VERSION' -Raw).Trim() | Should-BeString (Get-HieraValue 'windows.mozilla_build.version')
    }
    It 'has the configured <Package> version' -ForEach @(
        @{ Package = 'psutil'; Key = 'psutil_version' }
        @{ Package = 'zstandard'; Key = 'zstandard_version' }
        @{ Package = 'pip'; Key = 'py3_pip_version' }
    ) {
        $output = & 'C:\mozilla-build\python3\python.exe' -m pip show $Package
        $LASTEXITCODE | Should-Be 0
        $version = $output | Select-String '^Version:' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }
        $version | Should-BeString (Get-HieraValue "windows.mozilla_build.$Key")
    }
    It 'sets TOOLTOOL_CACHE' {
        [Environment]::GetEnvironmentVariable('TOOLTOOL_CACHE', 'Machine') | Should-BeString 'C:\builds\tooltool_cache'
    }
    It 'uses a local Mercurial cache' {
        [Environment]::GetEnvironmentVariable('HG_CACHE', 'Machine') | Should-MatchString '^[CD]:\\hg-cache$'
    }
    if (-not $Win10 -and -not $Server) {
        It 'does not map Y:' { Test-Path 'Y:\' | Should-BeFalse }
    }
    It 'does not configure the removed pip download cache' {
        Get-Content 'C:\ProgramData\pip\pip.ini' -Raw | Should-NotMatchString '(?im)^download-cache\s*='
        [string][Environment]::GetEnvironmentVariable('PIP_DOWNLOAD_CACHE', 'Machine') | Should-BeEmptyString
    }
    It 'does not have <_>' -ForEach @('C:\pip-cache', 'D:\pip-cache') { Test-Path $_ | Should-BeFalse }
}
