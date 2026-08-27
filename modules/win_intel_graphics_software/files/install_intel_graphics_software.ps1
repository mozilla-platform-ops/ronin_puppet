# install_intel_graphics_software.ps1
# Intel Graphics Software - the AppUp.IntelArcSoftware MSIX, which is what registers
# IntelGraphicsSoftwareService.
#
# RELOPS-2487. Goal is to REPLICATE PRODUCTION, and production is not uniform:
#   NUC13 (win11-64-24h2-hw)     : HAS IntelGraphicsSoftwareService  -> Ensure present
#   NUC12 (win11-64-24h2-hw-ref) : does NOT have it                  -> Ensure absent
#
# One golden WIM serves both platforms and the bake provisions the MSIX image-wide, so on
# a pre-baked image "just don't install it" is not available to the NUC12 pools - by the
# time puppet runs, it is already in the image. They need an ACTIVE removal, exactly like
# win_disable_services::enable_appxsvc had to actively undo the baked AppXSvc disable.
#
# Ensure present:
#   service already there  -> no-op (start it if stopped). This is the deploy-time case on
#                             a node built from a WIM that already has it.
#   service absent         -> run the staged Intel installer. This is the bake-time case.
# Ensure absent:
#   remove the provisioned + installed package so no user gets it and the service goes away.
#
# It never downloads. The installer lives in hardwareimaging, which is Entra-only (an
# anonymous GET returns 409): only the bake build host has an identity, so
# prepare-base-vhdx stages the file to C:\bake\extras during the bake. Note the installer
# is run WITHOUT --noExtras - that flag is precisely what skips
# Resources/Extras/IntelGraphicsSoftware_<ver>_Release.exe.

param(
    [ValidateSet('present','absent')]
    [string] $Ensure         = 'present',
    [string] $InstallerPath  = 'C:\bake\extras\gfx_win_*.exe',
    [string] $ServiceName    = 'IntelGraphicsSoftwareService',
    [string] $PackageMatch   = 'IntelArcSoftware|IntelGraphicsSoftware',
    # Best-effort by default: a missing installer must not fail the whole catalog.
    [switch] $FailIfMissing
)

$Script:Version = 'install_intel_graphics_software.ps1 2026-08-26 v2'

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
    # Write-Log call inside a function that returns a value corrupts that return. That exact
    # bug (Get-AppxSnapshot returning Object[]) PXE-looped the fleet on 2026-08-21.
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

function Get-GraphicsSoftwareService {
    [CmdletBinding()]
    param([string] $Name)
    return (Get-Service -Name $Name -ErrorAction SilentlyContinue)
}

$ErrorActionPreference = 'Continue'
Write-Log -message ("intel_graphics_software :: starting ({0}) Ensure={1}" -f $Script:Version, $Ensure) -severity 'DEBUG'

# ---------------------------------------------------------------- Ensure absent
if ($Ensure -eq 'absent') {
    $svc = Get-GraphicsSoftwareService -Name $ServiceName
    $removedAny = $false

    try {
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop |
                  Where-Object { $_.DisplayName -match $PackageMatch })
        foreach ($p in $prov) {
            Write-Log -message ("intel_graphics_software :: removing provisioned {0} {1}" -f $p.DisplayName, $p.Version) -severity 'INFO'
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
                $removedAny = $true
            } catch {
                Write-Log -message ("intel_graphics_software :: provisioned removal failed for {0}: {1}" -f $p.PackageName, $_.Exception.Message) -severity 'WARN'
            }
        }
    } catch {
        Write-Log -message ("intel_graphics_software :: could not enumerate provisioned packages: {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    try {
        $inst = @(Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $_.Name -match $PackageMatch })
        foreach ($p in $inst) {
            Write-Log -message ("intel_graphics_software :: removing installed {0} {1}" -f $p.Name, $p.Version) -severity 'INFO'
            try {
                Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
                $removedAny = $true
            } catch {
                Write-Log -message ("intel_graphics_software :: installed removal failed for {0}: {1}" -f $p.PackageFullName, $_.Exception.Message) -severity 'WARN'
            }
        }
    } catch {
        # Expected wherever AppXSvc is disabled; the provisioned removal above is the one
        # that matters for a freshly deployed node with no extra user profiles yet.
        Write-Log -message ("intel_graphics_software :: could not enumerate installed packages (AppXSvc disabled?): {0}" -f $_.Exception.Message) -severity 'WARN'
    }

    $svc = Get-GraphicsSoftwareService -Name $ServiceName
    if ($svc) {
        Write-Log -message ("intel_graphics_software :: {0} still registered after removal (start={1} status={2}); a reboot usually clears it" -f `
            $ServiceName, $svc.StartType, $svc.Status) -severity 'WARN'
    } else {
        Write-Log -message ("intel_graphics_software :: {0} not present - matches the NUC12 production reference" -f $ServiceName) -severity 'INFO'
    }
    Write-Log -message ("intel_graphics_software :: complete (absent, removedAny={0})" -f $removedAny) -severity 'DEBUG'
    exit 0
}

# --------------------------------------------------------------- Ensure present
$svc = Get-GraphicsSoftwareService -Name $ServiceName
if ($svc) {
    Write-Log -message ("intel_graphics_software :: {0} already present (start={1} status={2}); nothing to do" -f `
        $ServiceName, $svc.StartType, $svc.Status) -severity 'DEBUG'
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
    # Deploy-time on a node whose WIM predates this change. Not fatal: the node works, it
    # just lacks the Intel software stack. Re-bake to fix.
    Write-Log -message ("{0} :: skipping (best-effort). Re-bake to stage it." -f $msg) -severity 'WARN'
    exit 0
}

Write-Log -message ("intel_graphics_software :: installing from {0} ({1:n0} bytes)" -f $installer.FullName, $installer.Length) -severity 'INFO'

# -s silent, -f force. NO --noExtras: the Extras folder is exactly where
# IntelGraphicsSoftware_<ver>_Release.exe lives.
$p = Start-Process -FilePath $installer.FullName -ArgumentList '-s', '-f' -Wait -PassThru -ErrorAction SilentlyContinue
$rc = if ($null -ne $p) { $p.ExitCode } else { -1 }
Write-Log -message ("intel_graphics_software :: installer exit code {0}" -f $rc) -severity 'INFO'

if (Get-GraphicsSoftwareService -Name $ServiceName) {
    Write-Log -message "intel_graphics_software :: $ServiceName registered" -severity 'INFO'
} else {
    Write-Log -message ("intel_graphics_software :: installer finished rc={0} but {1} is still absent" -f $rc, $ServiceName) -severity 'WARN'
}

# Provisioned (image-level) is what survives sysprep /generalize. A per-user-only install
# would be stripped from the golden WIM, so surface which one we actually got.
try {
    $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -match $PackageMatch })
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
