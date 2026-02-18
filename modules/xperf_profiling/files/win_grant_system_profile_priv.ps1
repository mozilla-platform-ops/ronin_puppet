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

    # Best-effort event log creation (avoid terminating failures / races)
    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or
            !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        # ignore
    }

    try {
        Write-EventLog -LogName $logName -Source $source `
            -EntryType $entryType -Category 0 -EventID $eventId `
            -Message $message -ErrorAction SilentlyContinue
    } catch {
        # ignore
    }

    if ([Environment]::UserInteractive) {
        $fc = @{
            'Information'  = 'White'
            'Error'        = 'Red'
            'Warning'      = 'DarkYellow'
            'SuccessAudit' = 'DarkGray'
        }[$entryType]
        Write-Host $message -ForegroundColor $fc
    }
}

function Add-ProfileSystemPerformanceRight {
    [CmdletBinding()]
    param()

    $Group = 'Mozilla_XPerf_users'
    $Right = 'SeSystemProfilePrivilege'  # "Profile system performance"

    Write-Log -message ("rights :: begin :: add '{0}' to {1}" -f $Group, $Right) -severity 'DEBUG'

    # Resolve group SID (local or domain, if resolvable)
    $sid = $null
    try {
        $sid = (New-Object System.Security.Principal.NTAccount($Group)).
               Translate([System.Security.Principal.SecurityIdentifier]).Value
        Write-Log -message ("rights :: resolved SID for '{0}' = {1}" -f $Group, $sid) -severity 'DEBUG'
    } catch {
        Write-Log -message ("rights :: FAILED to resolve SID for '{0}': {1}" -f $Group, $_.Exception.Message) -severity 'ERROR'
        Write-Log -message ("rights :: hint: if it's a domain group, try hardcoding 'MOZILLA\{0}' (or correct domain prefix)" -f $Group) -severity 'WARN'
        throw
    }

    $tmp = Join-Path $env:TEMP ("secpol_{0}" -f (Get-Random))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    $cfg = Join-Path $tmp "secpol.cfg"
    $inf = Join-Path $tmp "secpol.inf"
    $sdb = Join-Path $tmp "secpol.sdb"

    try {
        Write-Log -message "rights :: exporting current policy (secedit /export)" -severity 'DEBUG'
        $null = & secedit /export /cfg $cfg 2>&1
        if (-not (Test-Path $cfg)) {
            throw "secedit export did not produce $cfg"
        }
    } catch {
        Write-Log -message ("rights :: export FAILED: {0}" -f $_.Exception.ToString()) -severity 'ERROR'
        throw
    }

    try {
        $content = Get-Content $cfg -Raw

        if ($content -notmatch '\[Privilege Rights\]') {
            Write-Log -message "rights :: [Privilege Rights] section missing; creating it" -severity 'WARN'
            $content += "`r`n[Privilege Rights]`r`n"
        }

        $pattern = ('^({0}\s*=\s*)(.*)$' -f [regex]::Escape($Right))
        $lines   = $content -split "`r?`n"

        $found = $false
        for ($i=0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $pattern) {
                $found    = $true
                $prefix   = $Matches[1]
                $existing = $Matches[2].Trim()

                $list = @()
                if ($existing) { $list = $existing -split '\s*,\s*' }

                $entry = "*$sid"  # secedit wants SIDs prefixed with '*'
                if ($list -contains $entry) {
                    Write-Log -message ("rights :: already present: {0} contains {1}" -f $Right, $entry) -severity 'INFO'
                } else {
                    $list += $entry
                    Write-Log -message ("rights :: adding {0} to {1}" -f $entry, $Right) -severity 'INFO'
                }

                $lines[$i] = $prefix + ($list -join ",")
                break
            }
        }

        if (-not $found) {
            Write-Log -message ("rights :: {0} not found; appending new entry" -f $Right) -severity 'WARN'
            $lines += ("{0} = *{1}" -f $Right, $sid)
        }

        # IMPORTANT: Unicode for secedit .inf
        Set-Content -Path $inf -Value ($lines -join "`r`n") -Encoding Unicode -Force
        Write-Log -message ("rights :: wrote updated policy to {0}" -f $inf) -severity 'DEBUG'
    } catch {
        Write-Log -message ("rights :: update FAILED: {0}" -f $_.Exception.ToString()) -severity 'ERROR'
        throw
    }

    try {
        Write-Log -message "rights :: applying policy (secedit /configure /areas USER_RIGHTS)" -severity 'DEBUG'
        $out = & secedit /configure /db $sdb /cfg $inf /areas USER_RIGHTS 2>&1
        $global:LASTEXITCODE = 0  # don't leak secedit exit code into caller if you're using this in Puppet flows
        Write-Log -message ("rights :: secedit output: {0}" -f (($out | Out-String).Trim())) -severity 'DEBUG'

        Write-Log -message "rights :: refreshing policy (gpupdate /force)" -severity 'DEBUG'
        $null = & gpupdate /force 2>&1
        $global:LASTEXITCODE = 0

        Write-Log -message ("rights :: complete :: '{0}' added to {1}" -f $Group, $Right) -severity 'INFO'
    } catch {
        Write-Log -message ("rights :: apply FAILED: {0}" -f $_.Exception.ToString()) -severity 'ERROR'
        throw
    } finally {
        # best-effort cleanup
        try { Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
}

# --- Main flow ---------------------------------------------------------------
try {
    Write-Log -message "rights :: start" -severity 'DEBUG'
    Add-ProfileSystemPerformanceRight
    Write-Log -message "rights :: done" -severity 'DEBUG'
    exit 0
} catch {
    Write-Log -message ("rights :: FATAL: {0}" -f $_.Exception.ToString()) -severity 'ERROR'
    exit 1
}
