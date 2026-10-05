# Run as a real generic-worker task with a writable cache mounted at "cache".
param (
    [Parameter(Mandatory = $true)][ValidateSet('C:', 'D:')][string] $ExpectedDrive,
    [switch] $ReuseCache
)
$ErrorActionPreference = 'Stop'
$root = $PWD.Path
Write-Output "Task=$root Profile=$env:USERPROFILE AppData=$env:APPDATA LocalAppData=$env:LOCALAPPDATA TEMP=$env:TEMP TMP=$env:TMP"
if ($root -notlike "$ExpectedDrive\tasks\task_*") { throw 'Unexpected task directory.' }
if ($env:USERPROFILE -notlike 'C:\Users\task_*') { throw 'Unexpected profile directory.' }
$profileTemp = Join-Path $env:USERPROFILE 'AppData\Local\Temp'
foreach ($path in @($env:TEMP, $env:TMP)) {
    if ($path -ne $profileTemp) { throw "Temporary files must stay in the Windows profile: $path" }
}
# Windows may retain LocalAppData in the profile. It must remain usable.
foreach ($path in @($root, $env:APPDATA, $env:LOCALAPPDATA, $env:TEMP)) {
    $probe = Join-Path $path ('dev-drive-probe-' + [guid]::NewGuid().ToString('N'))
    Set-Content -LiteralPath $probe -Value 'writable'
    Remove-Item -LiteralPath $probe
}
if ((Get-Item "$ExpectedDrive\tasks").Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'Task storage is a reparse point.'
}
if ($ReuseCache) {
    if ((Get-Content cache\proof.txt) -ne 'cache survived') { throw 'Cache was not preserved.' }
    Set-Content cache\proof.txt 'link survived'
    if ((Get-Content cache\hardlink.txt) -ne 'link survived') { throw 'Cache hardlink was not preserved.' }
} else {
    Set-Content cache\proof.txt 'cache survived'
    New-Item -ItemType HardLink -Path cache\hardlink.txt -Target cache\proof.txt | Out-Null
}
Write-Output 'PASS: task paths, profile access, temporary files, and cache data'
