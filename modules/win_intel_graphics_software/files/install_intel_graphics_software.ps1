# install_intel_graphics_software.ps1
# Installs Intel Graphics Software (the AppUp.IntelArcSoftware MSIX, which is what
# registers IntelGraphicsSoftwareService) from Intel's graphics installer.
#
# RELOPS-2487. Production MDT nodes have IntelGraphicsSoftwareService; nodes deployed
# from the pre-baked WIM do not, because the MU-catalog driver cab carries the DCH INF
# only. Under DCH the graphics *software* is a separate Store-delivered MSIX that Windows
# Update fetches as a driver companion app, and our images have WU disabled by design, so
# it never arrives.
#
# Intel's full installer carries it as Resources/Extras/IntelGraphicsSoftware_<ver>_Release.exe.
# The existing win_packages::drivers::intel_gfx class passes --noExtras, which is exactly
# the flag that skips that folder. This script deliberately does NOT pass it.
#
# STAGE AT BAKE / INSTALL AT DEPLOY, and note WHY it has to be that way: the installer
# lives in the 'hardwareimaging' storage account, which is Entra-only (anonymous GET
# returns 409). The bake BUILD HOST holds a managed identity and can azcopy it in; a
# deployed NUC has no Azure identity and cannot. So the bake stages the installer into
# the image and runs it there, and at deploy this script finds the service already
# present and no-ops.

param(
    # Local path (or glob) the bake stages the Intel installer to.
    [string] $InstallerPath = 'C:\bake\extras\gfx_win_*.exe',
    [string] $ServiceName   = 'IntelGraphicsSoftwareService',
    # Best-effort by default: a missing installer must not fail the whole catalog.
    [switch] $FailIfMissing
)

$Script:Version = 'install_intel_graphics_software.ps1 2026-08-26 v1'

function Write-Log {
    param (
        [string] $message,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string] $severity = 'INFO',
        [string] $source   = 'BootStrap',
        [string] $logName  = 'Application'
    )

    $entryType = 'Information'
    $eventId   = 1
    switch ($severity) {
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information';  $eventId = 1; break }
    }

    $fc = @{
        'Information'  = 'White'
        'Error'        = 'Red'
        'Warning'      = 'DarkYellow'
        'SuccessAudit' = 'DarkGray'
    }[$entryType]

    # Write-Host, never Write-Output: Write-Output puts the string on the PIPELINE, so a
    # Write-Log call inside a function that returns a value corrupts that return. That
    # exact bug (Get-AppxSnapshot returning Object[]) PXE-looped the fleet on 2026-08-21.
    try {
        if ($fc) { Write-Host $message -ForegroundColor $fc } else { Write-Host $message }
    } catch { }

    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source -ErrorAction SilentlyContinue | Out-Null
        }
    } catch { }
    try {
        Write-EventLog -LogName $logName -Source $source -EntryType $entryType `
            -Category 0 -EventID $eventId -Message $message -ErrorAction SilentlyContinue
    } catch { }
}

function Test-GraphicsSoftwarePresent {
    [CmdletBinding()]
    param([string] $Name)

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) { return $true }
    return $false
}

$ErrorActionPreference = 'Continue'
Write-Log -message ("intel_graphics_software :: starting ({0})" -f $Script:Version) -severity 'DEBUG'

if (Test-GraphicsSoftwarePresent -Name $ServiceName) {
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    Write-Log -message ("intel_graphics_software :: {0} already present (start={1} status={2}); nothing to do" -f `
        $ServiceName, $svc.StartType, $svc.Status) -severity 'DEBUG'

    # Present but not running is worth correcting - it is Automatic on production.
    if ($svc.Status -ne 'Running') {
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            Write-Log -message "intel_graphics_software :: started $ServiceName" -severity 'INFO'
        } catch {
            Write-Log -message ("intel_graphics_software :: could not start {0}: {1}" -f $ServiceName, $_.Exception.Message) -severity 'WARN'
        }
    }
    Write-Log -message 'intel_graphics_software :: complete' -severity 'DEBUG'
    exit 0
}

$installer = Get-ChildItem -Path $InstallerPath -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $installer) {
    $msg = "intel_graphics_software :: $ServiceName absent and no installer at '$InstallerPath'"
    if ($FailIfMissing) {
        Write-Log -message ("{0} :: FAILING as requested" -f $msg) -severity 'ERROR'
        exit 1
    }
    # Deploy-time on a node whose WIM predates this change, or any node where the bake did
    # not stage the installer. Not fatal: the node is functional, it just lacks the Intel
    # software stack. Re-bake to fix.
    Write-Log -message ("{0} :: skipping (best-effort). Re-bake to stage it." -f $msg) -severity 'WARN'
    exit 0
}

Write-Log -message ("intel_graphics_software :: installing from {0} ({1:n0} bytes)" -f $installer.FullName, $installer.Length) -severity 'INFO'

# -s silent, -f force. NOTE: no --noExtras - the Extras folder is precisely where
# IntelGraphicsSoftware_<ver>_Release.exe lives.
$p = Start-Process -FilePath $installer.FullName -ArgumentList '-s', '-f' -Wait -PassThru -ErrorAction SilentlyContinue
$rc = if ($null -ne $p) { $p.ExitCode } else { -1 }
Write-Log -message ("intel_graphics_software :: installer exit code {0}" -f $rc) -severity 'INFO'

if (Test-GraphicsSoftwarePresent -Name $ServiceName) {
    Write-Log -message "intel_graphics_software :: $ServiceName registered" -severity 'INFO'
} else {
    Write-Log -message ("intel_graphics_software :: installer finished rc={0} but {1} is still absent" -f $rc, $ServiceName) -severity 'WARN'
}

# Provisioned (image-level) is what survives sysprep /generalize. Per-user-only install
# would be stripped from the golden WIM, so surface which one we actually got.
try {
    $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -match 'IntelArcSoftware|IntelGraphicsSoftware' })
    Write-Log -message ("intel_graphics_software :: provisioned packages matching: {0}" -f $prov.Count) -severity 'INFO'
    foreach ($x in $prov) { Write-Log -message ("intel_graphics_software ::   {0} {1}" -f $x.DisplayName, $x.Version) -severity 'INFO' }
    if ($prov.Count -eq 0) {
        Write-Log -message 'intel_graphics_software :: NOT provisioned image-level - sysprep /generalize would strip it from the WIM' -severity 'WARN'
    }
} catch {
    Write-Log -message ("intel_graphics_software :: could not enumerate provisioned packages: {0}" -f $_.Exception.Message) -severity 'WARN'
}

Write-Log -message 'intel_graphics_software :: complete' -severity 'DEBUG'
exit 0
