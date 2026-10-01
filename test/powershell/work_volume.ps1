# Kitchen runs this after Puppet convergence. It can also run on an idle alpha VM.
$ErrorActionPreference = 'Stop'
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
    if ((Get-Content "$destination\probe.txt") -ne 'preserve across setup') {
        throw 'Repeated setup or cache-to-task rename lost data.'
    }
    foreach ($name in @('tasks', 'caches', 'downloads', 'hg-shared')) {
        if ((Get-Item "C:\$name").LinkType -ne 'Junction') { throw "C:\$name is not a junction." }
    }
    $volume = Get-Volume -FileSystemLabel 'Task Work Volume' -ErrorAction SilentlyContinue
    if ($volume -and [Environment]::OSVersion.Version.Build -ge 26100) {
        if ($volume.FileSystem -ne 'ReFS') { throw 'The work volume is not ReFS.' }
        fsutil.exe devdrv query 'C:\work-volume'
        if ($LASTEXITCODE -ne 0) { throw 'The work volume is not a Dev Drive.' }
    }
    Write-Output 'PASS: repeated work-volume setup and cache-to-task rename'
} finally {
    Remove-Item $source, $destination -Recurse -Force -ErrorAction SilentlyContinue
}
