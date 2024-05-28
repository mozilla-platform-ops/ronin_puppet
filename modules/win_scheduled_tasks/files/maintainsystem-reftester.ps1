<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'MaintainSystem',
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
        Write-Host -object $message -ForegroundColor $fc
    }
}

function Run-MaintainSystem {
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        #Remove-OldTaskDirectories
        Get-ChildItem "$env:systemdrive\logs\old" -Recurse -File | Where-Object CreationTime -lt  (Get-Date).AddDays(-7)  | Remove-Item -Force
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Remove-OldTaskDirectories {
    param (
        [string[]] $targets = @('Z:\task_*', 'C:\Users\task_*')
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        foreach ($target in ($targets | Where-Object { (Test-Path -Path ('{0}:\' -f $_[0]) -ErrorAction SilentlyContinue) })) {
            $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.LastWriteTime })
            if ($all_task_paths.length -gt 1) {
                Write-Log -message ('{0} :: {1} task directories detected matching pattern: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths.length, $target) -severity 'INFO'
                $old_task_paths = $all_task_paths[0..($all_task_paths.Length - 2)]
                foreach ($old_task_path in $old_task_paths) {
                    try {
                        & takeown.exe @('/a', '/f', $old_task_path, '/r', '/d', 'Y')
                        & icacls.exe @($old_task_path, '/grant', 'Administrators:F', '/t')
                        Remove-Item -Path $old_task_path -Force -Recurse
                        Write-Log -message ('{0} :: removed task directory: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime) -severity 'INFO'
                    }
                    catch {
                        Write-Log -message ('{0} :: failed to remove task directory: {1}, with last write time: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime, $_.Exception.Message) -severity 'ERROR'
                    }
                }
            }
            elseif ($all_task_paths.length -eq 1) {
                Write-Log -message ('{0} :: a single task directory was detected at: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths[0].FullName, $all_task_paths[0].LastWriteTime) -severity 'DEBUG'
            }
            else {
                Write-Log -message ('{0} :: no task directories detected matching pattern: {1}' -f $($MyInvocation.MyCommand.Name), $target) -severity 'DEBUG'
            }
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Check-RoninNodeOptions {
    param (
        [string] $inmutable = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").inmutable,
        [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid"
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        Write-Host $inmutable
        if ($inmutable -eq 'true') {
            Write-Log -message  ('{0} :: Node is set to be inmutable' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Remove-Item -path $lock -ErrorAction SilentlyContinue
            write-host New-item -path $flagfile
            Exit-PSSession
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Function UpdateRonin {
    param (
        [string] $sourceOrg,
        [string] $sourceRepo,
        [string] $sourceBranch,
        [string] $ronin_repo = "$env:systemdrive\ronin"
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $sourceOrg = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Organisation' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Organisation').Organisation } else { 'mozilla-platform-ops' })
        $sourceRepo = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Repository' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Repository').Repository } else { 'ronin_puppet' })
        $sourceBranch = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Branch' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\ronin_puppet\Source' -Name 'Branch').Branch } else { 'master' })

        Set-Location $ronin_repo
        git config --global --add safe.directory "C:/ronin"
        git pull https://github.com/$sourceOrg/$sourceRepo $sourceBranch
        $git_exit = $LastExitCode
        if ($git_exit -eq 0) {
            $git_hash = (git rev-parse --verify HEAD)
            Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
            Write-Log -message  ('{0} :: Checking/pulling updates from https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
        }
        else {
            # Fall back to clone if pull fails
            Write-Log -message  ('{0} :: Git pull failed! https://github.com/{1}/{2}. Branch: {3}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev)) -severity 'DEBUG'
            Write-Log -message  ('{0} :: Deleting old repository and cloning repository .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Move-item -Path $ronin_repo\manifests\nodes.pp -Destination $env:TEMP\nodes.pp
            Move-item -Path $ronin_repo\data\secrets\vault.yaml -Destination $env:TEMP\vault.yaml
            #Remove-Item -Recurse -Force $ronin_repo
            Start-Sleep -s 2
            git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
            Move-item -Path $env:TEMP\nodes.pp -Destination $ronin_repo\manifests\nodes.pp
            Move-item -Path $env:TEMP\vault.yaml -Destination $ronin_repo\data\secrets\vault.yaml
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
function Puppet-Run {
    param (
        [int] $exit,
        [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
        [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
        [string] $run_to_success = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").runtosuccess,
        [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
        [string] $logdir = "$env:systemdrive\logs",
        [string] $fail_dir = "$env:systemdrive\fail_logs",
        [string] $log_file = "$datetime-puppetrun.log",
        [string] $datetime = (get-date -format yyyyMMdd-HHmm),
        [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid"
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {

        Check-RoninNodeOptions
        UpdateRonin

        # Setting Env variabes for PuppetFile install and Puppet run
        # The ssl variables are needed for R10k
        Write-Log -message  ('{0} :: Setting Puppet enviroment.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        $env:path = "$env:programfiles\Puppet Labs\Puppet\puppet\bin;$env:programfiles\Puppet Labs\Puppet\bin;$env:path"
        $env:SSL_CERT_FILE = "$env:programfiles\Puppet Labs\Puppet\puppet\ssl\cert.pem"
        $env:SSL_CERT_DIR = "$env:programfiles\Puppet Labs\Puppet\puppet\ssl"
        $env:FACTER_env_windows_installdir = "$env:programfiles\Puppet Labs\Puppet"
        $env:HOMEPATH = "\Users\Administrator"
        $env:HOMEDRIVE = "C:"
        $env:PL_BASEDIR = "$env:programfiles\Puppet Labs\Puppet"
        $env:PUPPET_DIR = "$env:programfiles\Puppet Labs\Puppet"
        $env:RUBYLIB = "$env:programfiles\Puppet Labs\Puppet\lib"
        $env:USERNAME = "Administrator"
        $env:USERPROFILE = "$env:systemdrive\Users\Administrator"

        # This is temporary and should be removed after the cloud_windows branch is merged
        # Hiera lookups will fail after the merge if this is not in place following the merge
        <#
      if((test-path $env:systemdrive\ronin\win_hiera.yaml)) {
          $hiera = "win_hiera.yaml"
      } else {
          $hiera = "hiera.yaml"
      }
      #>
        # this will break Win 10 1803 if this is merged into the master brnach
        $hiera = "hiera.yaml"

        # Needs to be removed from path or a wrong puppet file will be used
        $env:path = ($env:path.Split(';') | Where-Object { $_ -ne "$env:programfiles\Puppet Labs\Puppet\puppet\bin" }) -join ';'
        If (!(test-path $fail_dir)) {
            New-Item -ItemType Directory -Force -Path $fail_dir
        }
        Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
        Write-Log -message  ('{0} :: Initiating Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=$hiera --logdest $logdir\$log_file
        [int]$puppet_exit = $LastExitCode

        if ($run_to_success -eq 'true') {
            if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
                if ($last_exit -eq 0) {
                    Write-Log -message  ('{0} :: Puppet apply failed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                    Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $puppet_exit
                    Remove-Item $lock -ErrorAction SilentlyContinue
                    # If the Puppet run fails send logs to papertrail
                    # Nxlog watches $fail_dir for files names *-puppetrun.log
                    Move-Item $logdir\$log_file -Destination $fail_dir
                    shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
                }
                elseif ($last_exit -ne 0) {
                    Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $puppet_exit
                    Remove-Item $lock
                    Move-Item $logdir\$log_file -Destination $fail_dir
                    Write-Log -message  ('{0} :: Puppet apply failed. Waiting 10 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                    Start-Sleep 600
                    shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
                }
            }
            elseif (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
                Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $puppet_exit
                Remove-Item -path $lock
                New-item -path $flagfile
            }
            else {
                Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name last_exit -type  dword -value $last_exit
                Move-Item $logdir\$log_file -Destination $fail_dir
                Remove-Item -path $lock
                shutdown @('-r', '-t', '600', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
            }
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function StartWorkerRunner {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        ## Checking for issues with the user profile.
        $lastBootTime = Get-WinEvent -LogName "System" -FilterXPath "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[EventID=12]]</Select></Query></QueryList>" |
            Select-Object -First 1 |
            ForEach-Object { $_.TimeCreated }
        $eventIDs = @(1511, 1515)

        $events = Get-WinEvent -LogName "Application" |
            Where-Object { $_.ID -in $eventIDs -and $_.TimeCreated -gt $lastBootTime } |
            Sort-Object TimeCreated -Descending | Select-Object -First 1

        if ($events) {
            Write-Log -message  ('{0} :: Possible User Profile Corruption. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Restart-Computer -Force
            exit
        }
        Start-Service -Name worker-runner
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

function Get-LoggedInUser {
    [CmdletBinding()]
    param (
        
    )
    
    @(((query user) -replace '\s{20,39}', ',,') -replace '\s{2,}', ',' | ConvertFrom-Csv)
}

$bootstrap_stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage
If ($bootstrap_stage -eq 'complete') {
    Run-MaintainSystem
    <#Write-Log -message  ('{0} :: Puppet exited with {1}' -f $($MyInvocation.MyCommand.Name), ($LastExitCode)) -severity 'DEBUG'
    ## Last catch if Puppet failed
    if (($puppet_exit -ne 0) -or ($puppet_exit -ne 2)) {
        Write-Log -message  ('{0} :: BROKEN Puppet exited with {1}' -f $($MyInvocation.MyCommand.Name), ($LastExitCode)) -severity 'DEBUG'
        #shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
        #exit
    }
    Write-Log -message  ('{0} :: Disabling Start Menu' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    ## Disable start menu. If shown can interfere with tests. #>
<#     while ($true) {
        $processname = "StartMenuExperienceHost"
        $process = Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue
        if ($null -ne $process) {
            Stop-Process -Name $processname -force
            break
        }
        Start-Sleep -Seconds 1
    } #>

    ## We're getting user profile corruption errors, so let's check that the user is logged in using quser.exe
    for ($i = 0; $i -lt 3; $i++) {
        if (Test-Path "C:\worker-runner\current-task-user.json") {
            $localuser = (Get-Content "C:\worker-runner\current-task-user.json" | ConvertFrom-Json -ErrorAction Stop).name
            $loggedInUser = (Get-LoggedInUser).UserName -replace ">"
            if ($loggedInUser -ne $localuser) {
                Write-Log -message  ('{0} :: User logged in is not the same as the user in worker-runner' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Write-Log -message  ('{0} :: User logged in: {1}' -f $($MyInvocation.MyCommand.Name), $loggedInUser) -severity 'DEBUG'
                Write-Log -message  ('{0} :: User in worker-runner: {1}' -f $($MyInvocation.MyCommand.Name), $localuser) -severity 'DEBUG'
                Start-Sleep -Seconds 10
            }
            else {
                Write-Log -message  ('{0} :: User logged in is the same as the user in worker-runner' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
                Write-Log -message  ('{0} :: User logged in: {1}' -f $($MyInvocation.MyCommand.Name), $loggedInUser) -severity 'DEBUG'
                Write-Log -message  ('{0} :: User in worker-runner: {1}' -f $($MyInvocation.MyCommand.Name), $localuser) -severity 'DEBUG'
                break
            }
        }
        if ($null -ne $loggedInUser) {
            break
        }
    }

    StartWorkerRunner
    start-sleep -s 30
    while ($true) {

        $lastBootTime = Get-WinEvent -LogName "System" -FilterXPath "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[EventID=12]]</Select></Query></QueryList>" |
            Select-Object -First 1 |
            ForEach-Object { $_.TimeCreated }
        $eventIDs = @(1511, 1515)

        $events = Get-WinEvent -LogName "Application" |
            Where-Object { $_.ID -in $eventIDs -and $_.TimeCreated -gt $lastBootTime } |
            Sort-Object TimeCreated -Descending | Select-Object -First 1

        if ($events) {
            Write-Log -message  ('{0} :: Possible User Profile Corruption After Worker Runner Start Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Restart-Computer -Force
            exit
        }

        $gw = (Get-process -name generic-worker -ErrorAction SilentlyContinue )
        $processname = "StartMenuExperienceHost"
        $process = Get-Process -Name StartMenuExperienceHost -ErrorAction SilentlyContinue
        if ($null -ne $process) {
            Stop-Process -Name $processname -force
        }
        if ($null -eq $gw) {
            # Wait to supress meesage if check is cuaght during a reboot.
            start-sleep -s 45
            Write-Log -message  ('{0} :: UNPRODUCTIVE: Generic-worker process not found after expected time' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            start-sleep -s 3
            #shutdown @('-s', '-t', '0', '-c', 'Shutdown: Worker is unproductive', '-f', '-d', '4:5')
        }
        else {
            start-sleep -s 120
        }
    }
}
else {
    Write-Log -message  ('{0} :: Bootstrap has not completed. EXITING!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Exit-PSSession
}
