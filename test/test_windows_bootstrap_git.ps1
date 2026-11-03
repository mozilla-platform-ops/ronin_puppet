$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$path = Join-Path (Split-Path -Parent $PSScriptRoot) '.kitchen/provision_windows.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$definition = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Install-KitchenGit'
}, $true)
. ([scriptblock]::Create($definition.Extent.Text))
function Test-Path { return $script:installed }
function Invoke-WebRequest {
    $script:downloads++
    if ($script:downloads -le $script:networkFailures) { throw 'download failed' }
}
function Start-Process {
    param($FilePath, $ArgumentList, [switch]$Wait, [switch]$PassThru)
    if (-not $Wait -or -not $PassThru) { throw 'Installer must wait and return its exit code.' }
    $script:installs++
    $script:installed = -not $script:missingGit
    return [pscustomobject]@{ ExitCode = $script:exitCode }
}
function Remove-Item { }
function Start-Sleep { }
$oldPath = $env:PATH
$oldTemp = $env:TEMP
$env:TEMP = [IO.Path]::GetTempPath()
try {
    foreach ($case in @(
        @{ name = 'fresh'; downloads = 1; installs = 1 },
        @{ name = 'already installed'; installed = $true; downloads = 0; installs = 0 },
        @{ name = 'transient download failure'; networkFailures = 1; downloads = 2; installs = 1 },
        @{ name = 'download retries exhausted'; networkFailures = 3; downloads = 3; installs = 0; failure = 'download failed' },
        @{ name = 'installer failed'; exitCode = 1603; downloads = 1; installs = 1; failure = 'rc=1603' },
        @{ name = 'missing executable'; missingGit = $true; downloads = 1; installs = 1; failure = 'did not produce git.exe' },
        @{ name = 'reboot requested'; exitCode = 3010; downloads = 1; installs = 1 }
    )) {
        $script:installed = $case.installed; $script:networkFailures = $case.networkFailures
        $script:missingGit = $case.missingGit; $script:exitCode = if ($case.exitCode) { $case.exitCode } else { 0 }
        $script:downloads = 0; $script:installs = 0
        $failure = ''
        try { Install-KitchenGit } catch { $failure = $_.Exception.Message }
        if (($case.failure -and $failure -notmatch $case.failure) -or (-not $case.failure -and $failure) -or
            $script:downloads -ne $case.downloads -or $script:installs -ne $case.installs) {
            throw "$($case.name): downloads=$script:downloads installs=$script:installs error=$failure"
        }
    }
} finally { $env:PATH = $oldPath; $env:TEMP = $oldTemp }
Write-Host 'Windows Kitchen Git bootstrap checks passed.'
