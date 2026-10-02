# Kitchen runs this after Puppet convergence. It can also run on an idle alpha VM.
$ErrorActionPreference = 'Stop'
$setup = "$env:ProgramData\PuppetLabs\ronin\configure_work_volume.ps1"
& $setup
$drive = 'D:'
$probe = 'work-volume-check-' + [guid]::NewGuid().ToString('N')
$source = "$drive\caches\$probe"
$destination = "$drive\tasks\$probe"
try {
    New-Item -ItemType Directory -Path $source | Out-Null
    Set-Content -LiteralPath "$source\probe.txt" -Value 'preserve across setup'
    & $setup
    # Directory.Move fails across volumes; Move-Item can hide a copy.
    [IO.Directory]::Move($source, $destination)
    if ((Get-Content "$destination\probe.txt") -ne 'preserve across setup') {
        throw 'Repeated setup or cache-to-task rename lost data.'
    }
    $runner = Get-Content 'C:\worker-runner\runner.yml' -Raw
    foreach ($name in @('tasks', 'caches', 'downloads')) {
        $path = "$drive\$name"
        if ((Get-Item $path).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "$path must be a real directory."
        }
        if ($runner -notmatch [regex]::Escape("${name}Dir: '$path'")) {
            throw "worker-runner does not use $path."
        }
    }
    $volume = Get-Volume -FileSystemLabel 'Task Work Volume' -ErrorAction SilentlyContinue
    if ($volume -and [Environment]::OSVersion.Version.Build -ge 26100) {
        if ($volume.FileSystem -ne 'ReFS') { throw 'The work volume is not ReFS.' }
        $devDrive = fsutil.exe devdrv query $drive
        if ($LASTEXITCODE -ne 0 -or $devDrive -notcontains 'This is a trusted developer volume.') {
            throw 'The work volume is not a trusted Dev Drive.'
        }
    }
    Write-Output 'PASS: repeated work-volume setup and cache-to-task rename'
} finally {
    Remove-Item $source, $destination -Recurse -Force -ErrorAction SilentlyContinue
}
