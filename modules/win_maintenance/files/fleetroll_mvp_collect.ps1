[CmdletBinding()]
param(
    # Where to write the JSON manifest
    [string]$OutFile = "C:\management_scripts\ronin_puppet_run.json",

    # Repo working dir (used to pull full git sha, branch, dirty, and remote)
    [string]$RepoPath = "C:\ronin",

    # Optional run metadata
    [int]$DurationSeconds = 0,

    # If not provided, we use registry last_run_exit (or NA)
    [Nullable[int]]$ExitCode = $null,

    # If not provided, computed as ($ExitCode -eq 0) when numeric; otherwise "NA"
    [Nullable[bool]]$Success = $null,

    # Optional file inputs (sha256 computed if present)
    [string]$VaultPath = "NA",
    [string]$OverridePath = "NA"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function NAIfBlank([object]$v) {
    if ($null -eq $v) { return "NA" }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return "NA" }
    return $s
}

function Get-RegValue([string]$path, [string]$name) {
    try {
        $item = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop
        return $item.$name
    } catch {
        return $null
    }
}

function Try-RunGit([string]$repoPath, [string]$args) {
    try {
        if (-not (Test-Path -LiteralPath $repoPath)) { return $null }

        $outFile = Join-Path $env:TEMP "git_out.txt"
        $errFile = Join-Path $env:TEMP "git_err.txt"

        $argList = @("-C", $repoPath) + ($args -split " ")

        $p = Start-Process -FilePath "git" -ArgumentList $argList `
            -NoNewWindow -PassThru -Wait `
            -RedirectStandardOutput $outFile `
            -RedirectStandardError $errFile

        if ($p.ExitCode -ne 0) { return $null }

        return (Get-Content -LiteralPath $outFile -Raw).Trim()
    } catch {
        return $null
    } finally {
        Remove-Item -LiteralPath (Join-Path $env:TEMP "git_out.txt"),(Join-Path $env:TEMP "git_err.txt") -ErrorAction SilentlyContinue
    }
}

function Get-FileSha256([string]$path) {
    try {
        if ([string]::IsNullOrWhiteSpace($path) -or $path -eq "NA") { return "NA" }
        if (-not (Test-Path -LiteralPath $path)) { return "NA" }
        return (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    } catch {
        return "NA"
    }
}

# Ensure output directory exists
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$regPath = "HKLM:\SOFTWARE\Mozilla\ronin_puppet"

# Registry values
$role        = NAIfBlank (Get-RegValue $regPath "role")
$org         = NAIfBlank (Get-RegValue $regPath "Organisation")
$repo        = NAIfBlank (Get-RegValue $regPath "Repository")
$branchReg   = NAIfBlank (Get-RegValue $regPath "Branch")
$gitHashReg  = NAIfBlank (Get-RegValue $regPath "GITHASH")
$lastRunExit = Get-RegValue $regPath "last_run_exit"

# ExitCode: param > registry > NA
if ($null -eq $ExitCode) {
    if ($null -ne $lastRunExit) {
        $ExitCode = [int]$lastRunExit
    }
}

# Git info from C:\ronin
$gitSha    = Try-RunGit $RepoPath "rev-parse HEAD"
$gitDirty  = Try-RunGit $RepoPath "status --porcelain"
$gitBr     = Try-RunGit $RepoPath "rev-parse --abbrev-ref HEAD"
$gitRemote = Try-RunGit $RepoPath "remote get-url origin"

# Determine git_sha (git > registry > NA)
if ([string]::IsNullOrWhiteSpace($gitSha)) {
    if ($gitHashReg -ne "NA") {
        $gitSha = $gitHashReg
    } else {
        $gitSha = "NA"
    }
}

# Determine git_dirty (boolean when known, else "NA")
$gitDirtyOut = "NA"
if ($null -ne $gitDirty) {
    if ([string]::IsNullOrWhiteSpace($gitDirty)) {
        $gitDirtyOut = $false
    } else {
        $gitDirtyOut = $true
    }
}

# Determine git_branch (git > registry > NA)
$gitBranch = "NA"
if (-not [string]::IsNullOrWhiteSpace($gitBr)) {
    $gitBranch = $gitBr
} elseif ($branchReg -ne "NA") {
    $gitBranch = $branchReg
}

# Determine git_repo (remote > constructed from Organisation/Repository > NA)
$gitRepoOut = "NA"
if (-not [string]::IsNullOrWhiteSpace($gitRemote)) {
    $gitRepoOut = $gitRemote
} elseif (($org -ne "NA") -and ($repo -ne "NA")) {
    if ($repo -match '^https?://') {
        $gitRepoOut = $repo
    } else {
        $gitRepoOut = "https://github.com/$org/$repo.git"
    }
}

# Determine success (param > computed from numeric exit code > "NA")
$successOut = "NA"
if ($null -ne $Success) {
    $successOut = [bool]$Success
} elseif ($null -ne $ExitCode) {
    if ([int]$ExitCode -eq 0) {
        $successOut = $true
    } else {
        $successOut = $false
    }
}

# Determine exit_code output (numeric when known, else "NA")
$exitCodeOut = "NA"
if ($null -ne $ExitCode) {
    $exitCodeOut = [int]$ExitCode
}

# vault/override sha
$vaultPathOut    = NAIfBlank $VaultPath
$overridePathOut = NAIfBlank $OverridePath

$vaultShaOut    = Get-FileSha256 $vaultPathOut
$overrideShaOut = Get-FileSha256 $overridePathOut

# Timestamp UTC ISO-8601 Z
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Build manifest
$manifest = [ordered]@{
    schema_version = 1
    ts             = $ts
    duration_s     = $DurationSeconds
    success        = $successOut
    exit_code      = $exitCodeOut
    role           = $role
    git_repo       = $gitRepoOut
    git_branch     = $gitBranch
    git_sha        = NAIfBlank $gitSha
    git_dirty      = $gitDirtyOut
    vault_path     = $vaultPathOut
    vault_sha      = $vaultShaOut
    override_path  = $overridePathOut
    override_sha   = $overrideShaOut
}

# Write pretty JSON
$manifest | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $OutFile -Encoding UTF8

Write-Host "Wrote manifest: $OutFile"
