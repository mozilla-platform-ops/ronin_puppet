# Run as Administrator

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
        Write-Host -Object $message -ForegroundColor $fc
    }
}

$sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
$sshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

if ($sshClient.State -ne 'Installed') {
    Write-Log "Installing OpenSSH Client..." 'INFO'
    Add-WindowsCapability -Online -Name $sshClient.Name
} else {
    Write-Log "OpenSSH Client is already installed." 'INFO'
}

if ($sshServer.State -ne 'Installed') {
    Write-Log "Installing OpenSSH Server..." 'INFO'
    Add-WindowsCapability -Online -Name $sshServer.Name
} else {
    Write-Log "OpenSSH Server is already installed." 'INFO'
}

Write-Log "Starting SSH service..." 'INFO'
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

$service = Get-Service -Name sshd
if ($service.Status -eq 'Running') {
    Write-Log "OpenSSH Server is running successfully." 'INFO'
} else {
    Write-Log "OpenSSH Server failed to start." 'ERROR'
}

Write-Log "Configuring firewall rules..." 'INFO'
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue

Write-Log "OpenSSH has been installed and configured successfully." 'INFO'
