[CmdletBinding()]
param(
    [string]$OutFile = "C:\management_scripts\ronin_puppet_run.json",
    [string]$RepoPath = "C:\ronin",
    [int]$DurationSeconds = 0,

    # Optional: if you still want to supply these from the caller (otherwise NA)
    [Nullable[int]]$ExitCode = $null,
    [Nullable[bool]]$Success = $null,

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

function Is-FullSha([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $false }
    return ($s -match '^[0-9a-fA-F]{40}$')
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

function Resolve-RepoPath([string]$primary) {
    $candidates = @(
        $primary,
        "C:\ronin",
        "C:\ronini"
    ) | Select-Object -Unique

    foreach ($p in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path -LiteralPath $p)) {
            if (Test-Path -LiteralPath (Join-Path $p ".git")) {
                return $p
            }
        }
    }
    return $null
}

function Get-GitFullSha-WithoutGit([string]$repoPath) {
    try {
        if (-not $repoPath) { return $null }
        $gitDir = Join-Path $repoPath ".git"
        if (-not (Test-Path -LiteralPath $gitDir)) { return $null }

        $headPath = Join-Path $gitDir "HEAD"
        if (-not (Test-Path -LiteralPath $headPath)) { return $null }

        $head = (Get-Content -LiteralPath $headPath -Raw).Trim()

        # Detached HEAD: HEAD contains the SHA
        if ($head -match '^[0-9a-fA-F]{40}$') {
            return $head.ToLowerInvariant()
        }

        # HEAD points to a ref: "ref: refs/heads/main"
        if ($head -match '^ref:\s+(.+)$') {
            $ref = $matches[1].Trim()
            $refFile = Join-Path $gitDir $ref.Replace('/', '\')

            # Loose ref
            if (Test-Path -LiteralPath $refFile) {
                $sha = (Get-Content -LiteralPath $refFile -Raw).Trim()
                if (Is-FullSha $sha) { return $sha.ToLowerInvariant() }
            }

            # Packed ref fallback
            $packed = Join-Path $gitDir "packed-refs"
            if (Test-Path -LiteralPath $packed) {
                foreach ($line in Get-Content -LiteralPath $packed) {
                    if ($line -match '^\s*#') { continue }
                    if ($line -match '^\s*\^') { continue }
                    if ($line -match '^([0-9a-fA-F]{40})\s+(.+)$') {
                        $sha2 = $matches[1]
                        $ref2 = $matches[2]
                        if ($ref2 -eq $ref -and (Is-FullSha $sha2)) {
                            return $sha2.ToLowerInvariant()
                        }
                    }
                }
            }
        }

        return $null
    } catch {
        return $null
    }
}

# Ensure output directory exists
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Force overwrite: remove existing file so Out-File can't preserve BOM/attrs issues
if (Test-Path -LiteralPath $OutFile) {
    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
}

$regPath = "HKLM:\SOFTWARE\Mozilla\ronin_puppet"

# Registry values
$role          = NAIfBlank (Get-RegValue $regPath "role")
$org           = NAIfBlank (Get-RegValue $regPath "Organisation")
$repo          = NAIfBlank (Get-RegValue $regPath "Repository")
$branchReg     = NAIfBlank (Get-RegValue $regPath "Branch")
$gitHashReg    = NAIfBlank (Get-RegValue $regPath "GITHASH")
$bootstrapStage = NAIfBlank (Get-RegValue $regPath "bootstrap_stage")

# bootstrap_complete: true only when stage == "complete" (case-insensitive)
$bootstrapComplete = $false
if ($bootstrapStage -ne "NA") {
    if ($bootstrapStage.ToString().Trim().ToLowerInvariant() -eq "complete") {
        $bootstrapComplete = $true
    }
}

# Resolve repo path (try C:\ronin and C:\ronini if needed)
$resolvedRepo = Resolve-RepoPath $RepoPath

# Git info (prefer git command, fallback to manual .git parsing)
$gitSha    = $null
$gitDirty  = $null
$gitBr     = $null
$gitRemote = $null

if ($resolvedRepo) {
    $gitSha    = Try-RunGit $resolvedRepo "rev-parse HEAD"
    $gitDirty  = Try-RunGit $resolvedRepo "status --porcelain"
    $gitBr     = Try-RunGit $resolvedRepo "rev-parse --abbrev-ref HEAD"
    $gitRemote = Try-RunGit $resolvedRepo "remote get-url origin"

    if (-not (Is-FullSha $gitSha)) {
        $manualSha = Get-GitFullSha-WithoutGit $resolvedRepo
        if (Is-FullSha $manualSha) {
            $gitSha = $manualSha
        }
    }
}

# Final fallback: registry hash (might be short)
if (-not (Is-FullSha $gitSha)) {
    if ($gitHashReg -ne "NA") {
        $gitSha = $gitHashReg
    } else {
        $gitSha = "NA"
    }
}

# git_dirty: boolean when known, else "NA"
$gitDirtyOut = "NA"
if ($null -ne $gitDirty) {
    $gitDirtyOut = -not [string]::IsNullOrWhiteSpace($gitDirty)
}

# git_branch: git > registry > NA
$gitBranch = "NA"
if (-not [string]::IsNullOrWhiteSpace($gitBr)) {
    $gitBranch = $gitBr
} elseif ($branchReg -ne "NA") {
    $gitBranch = $branchReg
}

# git_repo: remote > constructed from Organisation/Repository > NA
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

# success + exit_code (still supported via params, otherwise NA)
$successOut = "NA"
if ($null -ne $Success) {
    $successOut = [bool]$Success
}

$exitCodeOut = "NA"
if ($null -ne $ExitCode) {
    $exitCodeOut = [int]$ExitCode
    if ($successOut -eq "NA") {
        # If caller provided ExitCode but not Success, derive it (0 == success)
        $successOut = ($exitCodeOut -eq 0)
    }
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
    schema_version      = 1
    ts                  = $ts
    duration_s          = $DurationSeconds
    success             = $successOut
    exit_code           = $exitCodeOut
    role                = $role
    git_repo            = $gitRepoOut
    git_branch          = $gitBranch
    git_sha             = NAIfBlank $gitSha
    git_dirty           = $gitDirtyOut
    vault_path          = $vaultPathOut
    vault_sha           = $vaultShaOut
    override_path       = $overridePathOut
    override_sha        = $overrideShaOut
    bootstrap_stage     = $bootstrapStage
    bootstrap_complete  = $bootstrapComplete
}

# Force overwrite output
$manifest | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $OutFile -Encoding UTF8 -Force

Write-Host "Wrote manifest: $OutFile"
if ($resolvedRepo) { Write-Host "Resolved repo path: $resolvedRepo" }
Write-Host "bootstrap_stage: $bootstrapStage"
Write-Host "bootstrap_complete: $bootstrapComplete"
Write-Host "git_sha: $($manifest.git_sha)"
