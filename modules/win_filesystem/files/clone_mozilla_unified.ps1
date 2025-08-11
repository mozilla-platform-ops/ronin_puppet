# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Variables from Puppet
$HgExePath = '<%= @hg_exe_path %>'
$RepositoryUrl = '<%= @mozilla_unified_url %>'
$CheckoutPath = '<%= @checkout_path %>'

# Function to write timestamped log messages
function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'BootStrap',
        [string] $logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }
    switch ($severity) {
        'DEBUG' {
            $entryType = 'SuccessAudit'
            $eventId = 2
            break
        }
        'WARN' {
            $entryType = 'Warning'
            $eventId = 3
            break
        }
        'ERROR' {
            $entryType = 'Error'
            $eventId = 4
            break
        }
        default {
            $entryType = 'Information'
            $eventId = 1
            break
        }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host  -object $message -ForegroundColor $fc
    }
}

try {
    Write-Log "Starting Mozilla Unified clone process"
    Write-Log "HgExePath: $HgExePath"
    Write-Log "RepositoryUrl: $RepositoryUrl"
    Write-Log "CheckoutPath: $CheckoutPath"
    
    # Check if hg.exe exists
    if (-not (Test-Path $HgExePath)) {
        Write-Log "ERROR: Mercurial executable not found at: $HgExePath"
        exit 1
    }
    
    Write-Log "Mercurial executable found"
    
    # Check if .hg directory already exists (repository already cloned)
    $hgDir = Join-Path $CheckoutPath ".hg"
    if (Test-Path $hgDir) {
        Write-Log "Repository already exists at $CheckoutPath, skipping clone"
        exit 0
    }
    
    Write-Log "Starting clone operation..."
    
    # Execute the clone command
    $process = Start-Process -FilePath $HgExePath -ArgumentList "clone", $RepositoryUrl, $CheckoutPath -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Log "Clone completed successfully"
        
        # Verify the clone was successful
        if (Test-Path $hgDir) {
            Write-Log "Verification: .hg directory created successfully"
            exit 0
        } else {
            Write-Log "ERROR: Clone appeared successful but .hg directory not found"
            exit 1
        }
    } else {
        Write-Log "ERROR: Clone failed with exit code $($process.ExitCode)"
        exit $process.ExitCode
    }
    
} catch {
    Write-Log "ERROR: Exception occurred during clone process: $($_.Exception.Message)"
    Write-Log "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
