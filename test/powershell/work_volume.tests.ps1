# Run on a fresh alpha worker after boot, before it takes tasks:
# Invoke-Pester .\test\powershell\work_volume.tests.ps1
Describe 'Azure task work volume' {
    It 'Keeps task and cache operations on one volume across repeated setup' {
        $setup = "$env:ProgramData\PuppetLabs\ronin\configure_work_volume.ps1"
        & $setup
        $probe = 'work-volume-check-' + [guid]::NewGuid().ToString('N')
        $source = "C:\caches\$probe"
        $destination = "C:\tasks\$probe"
        try {
            New-Item -ItemType Directory -Path $source | Out-Null
            Set-Content -LiteralPath "$source\probe.txt" -Value 'preserve across setup'
            & $setup
            # Directory.Move fails across volumes; Move-Item can hide a copy.
            [IO.Directory]::Move($source, $destination)
            Get-Content "$destination\probe.txt" | Should -Be 'preserve across setup'
            foreach ($name in @('tasks', 'caches', 'downloads', 'hg-shared')) {
                (Get-Item "C:\$name").LinkType | Should -Be 'Junction'
            }
            $volume = Get-Volume -FileSystemLabel 'Task Work Volume' -ErrorAction SilentlyContinue
            if ($volume -and [Environment]::OSVersion.Version.Build -ge 26100) {
                $volume.FileSystem | Should -Be 'ReFS'
                fsutil.exe devdrv query 'C:\work-volume'
                $LASTEXITCODE | Should -Be 0
            }
        } finally {
            Remove-Item $source, $destination -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
