# C:\management_scripts\Write-RoninPuppetManifest.ps1
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
        $p = Start-Process -FilePath "git" -ArgumentList @("-C", $repoPath) + ($args -split " ") `
            -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\git_out.txt" -RedirectStandardError "$env:TEMP\git_err.txt"
        if ($p.ExitCode -ne 0) { return $null }
        return (Get-Content -LiteralPath "$env:TEMP\git_out.txt" -Raw).Trim()
    } catch {
        return $null
    } finally {
        Remove-Item -LiteralPath "$env:TEMP\git_out.txt","$env:TEMP\git_err.txt" -ErrorAction SilentlyContinue
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
$role          = NAIfBlank (Get-RegValue $regPath "role")
$org           = NAIfBlank (Get-RegValue $regPath "Organisation")
$repo          = NAIfBlank (Get-RegValue $regPath "Repository")
$branchReg     = NAIfBlank (Get-RegValue $regPath "Branch")
$gitHashReg    = NAIfBlank (Get-RegValue $regPath "GITHASH")
$lastRunExit   = Get-RegValue $regPath "last_run_exit"

# ExitCode: param > registry > NA
if ($null -eq $ExitCode) {
    if ($null -ne $lastRunExit) {
        # last_run_exit is typically a DWORD
        $ExitCode = [int]$lastRunExit
    }
}

# Git info from C:\ronin
$gitSha   = Try-RunGit $RepoPath "rev-parse HEAD"
$gitDirty = Try-RunGit $RepoPath "status --porcelain"
$gitBr    = Try-RunGit $RepoPath "rev-parse --abbrev-ref HEAD"
$gitRemote= Try-RunGit $RepoPath "remote get-url origin"

if ([string]::IsNullOrWhiteSpace($gitSha)) {
    # Fallback to registry hash if git isn't available / repo missing
    $gitSha = ($gitHashReg -ne "NA") ? $gitHashReg : "NA"
}

$gitDirtyBool = "NA"
if ($null -ne $gitDirty) {
    $gitDirtyBool = -not [string]::IsNullOrWhiteSpace($gitDirty)
}

# Branch: git > registry > NA
$gitBranch = "NA"
if (-not [string]::IsNullOrWhiteSpace($gitBr)) {
    $gitBranch = $gitBr
} elseif ($branchReg -ne "NA") {
    $gitBranch = $branchReg
}

# Repo URL: git remote > constructed from Organisation/Repository > NA
$gitRepo = "NA"
if (-not [string]::IsNullOrWhiteSpace($gitRemote)) {
    $gitRepo = $gitRemote
} elseif (($org -ne "NA") -and ($repo -ne "NA")) {
    # if Repository already looks like a URL, keep it; otherwise construct GitHub URL
    if ($repo -match '^https?://') {
        $gitRepo = $repo
    } else {
        $gitRepo = "https://github.com/$org/$repo.git"
    }
}

# Success: param > computed from numeric exit code > "NA"
$successOut = "NA"
if ($null -ne $Success) {
    $successOut = [bool]$Success
} elseif ($null -ne $ExitCode) {
    $successOut = ([int]$ExitCode -eq 0)
}

# vault/override sha
$vaultPathOut    = NAIfBlank $VaultPath
$overridePathOut = NAIfBlank $OverridePath

$vaultSha    = Get-FileSha256 $vaultPathOut
$overrideSha = Get-FileSha256 $overridePathOut

# Timestamp UTC ISO-8601 Z
$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Build manifest
$manifest = [ordered]@{
    schema_version = 1
    ts             = $ts
    duration_s     = $DurationSeconds
    success        = $successOut
    exit_code      = ($null -ne $ExitCode) ? [int]$ExitCode : "NA"
    role           = $role
    git_repo       = $gitRepo
    git_branch     = $gitBranch
    git_sha        = NAIfBlank $gitSha
    git_dirty      = $gitDirtyBool
    vault_path     = $vaultPathOut
    vault_sha      = $vaultSha
    override_path  = $overridePathOut
    override_sha   = $overrideSha
}

# Write pretty JSON
$manifest | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $OutFile -Encoding UTF8

Write-Host "Wrote manifest: $OutFile"
