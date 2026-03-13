[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Role,

    [string[]]$TestFile,

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Ensure-PowerShellGallery {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    }

    $gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($null -eq $gallery) {
        Register-PSRepository -Default
        $gallery = Get-PSRepository -Name PSGallery
    }

    if ($gallery.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    }
}

function Get-LatestAvailableModule {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
}

function Ensure-Module {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [int]$MinimumMajorVersion = 0
    )

    $module = Get-LatestAvailableModule -Name $Name
    if ($null -eq $module -or $module.Version.Major -lt $MinimumMajorVersion) {
        Ensure-PowerShellGallery
        Install-Module -Name $Name -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
        $module = Get-LatestAvailableModule -Name $Name
    }

    if ($null -eq $module) {
        throw "Unable to locate PowerShell module '$Name'."
    }

    Import-Module -Name $module.Path -Force -Global
}

function ConvertTo-Hashtable {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
        }
        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $result = @()
        foreach ($item in $InputObject) {
            $result += ,(ConvertTo-Hashtable -InputObject $item)
        }
        return $result
    }

    if ($InputObject -is [pscustomobject]) {
        $result = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $result
    }

    return $InputObject
}

function Merge-HashTables {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Base,

        [Parameter(Mandatory = $true)]
        [hashtable]$Overlay
    )

    $result = @{}

    foreach ($key in $Base.Keys) {
        if ($Base[$key] -is [hashtable] -and $Overlay.ContainsKey($key) -and $Overlay[$key] -is [hashtable]) {
            $result[$key] = Merge-HashTables -Base $Base[$key] -Overlay $Overlay[$key]
        }
        else {
            $result[$key] = $Base[$key]
        }
    }

    foreach ($key in $Overlay.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Overlay[$key] -is [hashtable]) {
            $result[$key] = Merge-HashTables -Base $result[$key] -Overlay $Overlay[$key]
        }
        else {
            $result[$key] = $Overlay[$key]
        }
    }

    return $result
}

function Get-ConfiguredTests {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$RoleName
    )

    $manifest = ConvertTo-Hashtable -InputObject (ConvertFrom-Yaml (Get-Content -Path $ManifestPath -Raw))
    if (-not $manifest.roles.ContainsKey($RoleName)) {
        throw "No Windows Pester test manifest entry found for role '$RoleName'."
    }

    return @($manifest.roles[$RoleName].tests)
}

$manifestPath = Join-Path $PSScriptRoot 'manifest.yml'
$testRoot = Join-Path $PSScriptRoot 'tests'
$supportModulePath = Join-Path $PSScriptRoot 'support\RoninKitchen.Windows.Tests.psm1'
$artifactsRoot = Join-Path $PSScriptRoot 'artifacts'

if (-not (Test-Path $manifestPath)) {
    throw "Unable to find manifest at $manifestPath."
}

if (-not (Test-Path $supportModulePath)) {
    throw "Unable to find support module at $supportModulePath."
}

Ensure-Module -Name 'Pester' -MinimumMajorVersion 5
Ensure-Module -Name 'powershell-yaml'
Import-Module -Name $supportModulePath -Force -Global

$selectedTests = if ($TestFile -and $TestFile.Count -gt 0) {
    $TestFile
}
else {
    Get-ConfiguredTests -ManifestPath $manifestPath -RoleName $Role
}

$resolvedTests = foreach ($name in $selectedTests) {
    $path = Join-Path $testRoot $name
    if (-not (Test-Path $path)) {
        throw "Unable to find Pester test file '$name' at $path."
    }
    (Resolve-Path $path).Path
}

$rolePath = Join-Path $RepoRoot "data\roles\$Role.yaml"
$windowsPath = Join-Path $RepoRoot 'data\os\Windows.yaml'

if (-not (Test-Path $rolePath)) {
    throw "Unable to find role data at $rolePath."
}

if (-not (Test-Path $windowsPath)) {
    throw "Unable to find Windows data at $windowsPath."
}

$roleData = ConvertTo-Hashtable -InputObject (ConvertFrom-Yaml (Get-Content -Path $rolePath -Raw))
$windowsData = ConvertTo-Hashtable -InputObject (ConvertFrom-Yaml (Get-Content -Path $windowsPath -Raw))
$combinedHiera = Merge-HashTables -Base $windowsData -Overlay $roleData

New-Item -Path $artifactsRoot -ItemType Directory -Force | Out-Null

$resultName = (($selectedTests -join '_') -replace '[^A-Za-z0-9._-]', '_') + '.xml'
$resultPath = Join-Path $artifactsRoot $resultName

$container = New-PesterContainer -Path $resolvedTests -Data @{ Hiera = $combinedHiera }
$configuration = New-PesterConfiguration
$configuration.Run.Container = $container
$configuration.Run.PassThru = $true
$configuration.Run.Exit = $false
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = $resultPath
$configuration.TestResult.TestSuiteName = "Kitchen $Role :: $($selectedTests -join ', ')"
$configuration.Output.Verbosity = 'Detailed'

Write-Host "Running Pester for role $Role against: $($selectedTests -join ', ')"
$result = Invoke-Pester -Configuration $configuration

if ($null -eq $result) {
    throw 'Invoke-Pester returned no result object.'
}

if ($result.FailedCount -gt 0) {
    Write-Host "Pester reported $($result.FailedCount) failed tests."
    exit $result.FailedCount
}

if ($result.Result -eq 'Failed') {
    Write-Host 'Pester returned a failed result.'
    exit 1
}

Write-Host "Pester passed. Results written to $resultPath"
exit 0
