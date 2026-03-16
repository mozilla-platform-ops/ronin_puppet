param(
    [Parameter(Mandatory)]
    [string]$Role
)

$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\ronin_puppet'
$testDir = "$repoRoot\test\pester"
$rolePath = "$repoRoot\data\roles\$Role.yaml"
$winPath = "$repoRoot\data\os\Windows.yaml"

# Install prerequisites
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module powershell-yaml -Force -ErrorAction Stop

# Remove built-in Pester v3 and install v5
$builtIn = Get-Module Pester -ListAvailable | Where-Object { $_.Version -lt '5.0' }
if ($builtIn) {
    $builtIn | ForEach-Object {
        $modPath = Split-Path $_.Path
        Remove-Item $modPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -ErrorAction Stop
Import-Module Pester -MinimumVersion 5.0

# Install TestHelpers module (Get-InstalledSoftware)
$dest = "$env:ProgramFiles\WindowsPowerShell\Modules\TestHelpers"
if (-not (Test-Path $dest)) { New-Item $dest -ItemType Directory -Force | Out-Null }
Copy-Item "$testDir\Helpers\*" "$dest\" -Recurse -Force
Import-Module TestHelpers -Force

# Load hiera YAML
if (-not (Test-Path $winPath)) {
    Write-Error "Windows hiera data not found: $winPath"
    exit 1
}
$WindowsHiera = ConvertFrom-Yaml (Get-Content -Path $winPath -Raw)

$RoleHiera = @{}
if (Test-Path $rolePath) {
    $RoleHiera = ConvertFrom-Yaml (Get-Content -Path $rolePath -Raw)
}

# Deep-merge: role-specific values overlay Windows defaults
function Merge-HashTables {
    param (
        [hashtable]$Base,
        [hashtable]$Overlay
    )
    $Result = @{}
    foreach ($key in $Base.Keys) {
        if ($Base[$key] -is [hashtable] -and $Overlay.ContainsKey($key) -and $Overlay[$key] -is [hashtable]) {
            $Result[$key] = Merge-HashTables -Base $Base[$key] -Overlay $Overlay[$key]
        }
        else {
            $Result[$key] = $Base[$key]
        }
    }
    foreach ($key in $Overlay.Keys) {
        if (-not $Result.ContainsKey($key)) {
            $Result[$key] = $Overlay[$key]
        }
    }
    return $Result
}

$CombinedHiera = Merge-HashTables -Base $WindowsHiera -Overlay $RoleHiera

# Load per-role test list
$configPath = "$testDir\configs\$Role.yaml"
if (-not (Test-Path $configPath)) {
    Write-Error "No test config found for role '$Role': $configPath"
    exit 1
}
$config = ConvertFrom-Yaml (Get-Content -Path $configPath -Raw)
if (-not $config.tests) {
    Write-Error "No tests listed in $configPath"
    exit 1
}

$tests = foreach ($t in $config.tests) {
    $path = Join-Path $testDir $t
    if (-not (Test-Path $path)) {
        Write-Error "Test file not found: $path"
        exit 1
    }
    Get-Item $path
}

Write-Host "Running $($tests.Count) Pester test files for role '$Role'..."

$Container = New-PesterContainer -Path $tests.FullName -Data @{ Hiera = $CombinedHiera }
$Configuration = New-PesterConfiguration
$Configuration.Run.Exit = $true
$Configuration.Run.Container = $Container
$Configuration.TestResult.Enabled = $true
$Configuration.TestResult.OutputPath = 'C:\PesterTestResults.xml'
$Configuration.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $Configuration
