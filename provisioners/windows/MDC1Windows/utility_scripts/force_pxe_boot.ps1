param(
    [switch]$single,
    [switch]$range,
    [switch]$pool,
    [switch]$cleanDDrive,
    [switch]$keepOSfiles,
    [string]$node,
    [string]$hw_class,
    [string]$start,
    [string]$end,
    [string]$pool_name,
    [switch]$listHwClass,
    [string]$domain_suffix = "wintest2.releng.mdc1.mozilla.com",
    [string]$local_script = "C:\management_scripts\force_pxe_install.ps1",
    [string]$yaml_url = "https://raw.githubusercontent.com/mozilla-platform-ops/ronin_puppet/win11hardware/provisioners/windows/MDC1Windows/pools.yml",
    [switch]$help
)

$singlePresent = -not [string]::IsNullOrWhiteSpace($single)
$rangePresent = -not [string]::IsNullOrWhiteSpace($range)
$poolPresent = -not [string]::IsNullOrWhiteSpace($pool)

if (-not $single -and -not $range -and -not $pool -and -not $help -and -not $cleanDDrive) {
    $choice = Read-Host "Neither single nor range parameters were provided. Enter `n'1' - for single node `n'2' - for range of nodes `n'3' - for entire pool `n'4' - for help `n'5' - for a list hw classes `n'q' - to quit `n"

    switch ($choice) {
        '1' {
            "Will need a range of nodes."
            $single = [bool]($single -ne $null)
        }
        '2' {
            Write-Host "Will need a range of nodes."
            $range = [bool]($range -ne $null)
        }
        '3' {
            Write-Host "Will need pool name."
            $pool = [bool]($single -ne $null)
        }
        '4' {
            Write-Host "Show help."
            $help = [bool]($single -ne $null)
        }
        '5' {
            Write-Host "Show help."
            $listHwClass = [bool]($single -ne $null)
        }
        'q' {
            Write-Host "Exiting script."
            exit
        }
        default {
            Write-Host "Invalid choice."
            $help = [bool]($single -ne $null)
        }
    }
}

$script:failed_ssh = @()

$content = @"
function Write-Log {
    param (
        [string] `$message,
        [string] `$severity = 'INFO',
        [string] `$source = 'BootStrap',
        [string] `$logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists(`$logName)) -or !([Diagnostics.EventLog]::SourceExists(`$source))) {
        New-EventLog -LogName `$logName -Source `$source
    }
    switch (`$severity) {
        'DEBUG' {
            `$entryType = 'SuccessAudit'
            `$eventId = 2
            break
        }
        'WARN' {
            `$entryType = 'Warning'
            `$eventId = 3
            break
        }
        'ERROR' {
            `$entryType = 'Error'
            `$eventId = 4
            break
        }
        default {
            `$entryType = 'Information'
            `$eventId = 1
            break
        }
    }
    Write-EventLog -LogName `$logName -Source `$source -EntryType `$entryType -Category 0 -EventID `$eventId -Message `$message
    if ([Environment]::UserInteractive) {
        `$fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[`$entryType]
        Write-Host  -object `$message -ForegroundColor `$fc
    }
}

function Set-PXE {
    param ()
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f `$MyInvocation.MyCommand.Name, (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        `$tempPath = "C:\\temp\\"
        New-Item -ItemType Directory -Force -Path `$tempPath -ErrorAction SilentlyContinue

        bcdedit /enum firmware > "`$tempPath\\firmware.txt"

        `$fwBootMgr = Select-String -Path "`$tempPath\\firmware.txt" -Pattern "{fwbootmgr}"
        if (!`$fwBootMgr){
            Write-Log -message  ('{0} :: Device is configured for Legacy Boot. Exiting!' -f `$MyInvocation.MyCommand.Name) -severity 'DEBUG'
            Exit 999
        }
        Try {
            `$pxeGUID = (( Get-Content `$tempPath\\firmware.txt | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop ).context.precontext)[0]

            `$pxeGUID = '{' + `$pxeGUID.split('{')[1]

            bcdedit /set "{fwbootmgr}" bootsequence "`$pxeGUID"

            Write-Log -message  ('{0} :: Device will PXE boot. Restarting' -f `$MyInvocation.MyCommand.Name) -severity 'DEBUG'
            Restart-Computer -Force
        }
        Catch {
            Write-Log -message  ('{0} :: Unable to set next boot to PXE. Exiting!' -f `$MyInvocation.MyCommand.Name) -severity 'DEBUG'
            Exit 888
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f `$MyInvocation.MyCommand.Name, (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Set-PXE
"@

function Clean-DDrive {
    param (
        [string]$NodeName
    )
    $removeCommand = "Get-ChildItem -Path D:\* -Recurse -Force | Where-Object { `$_.FullName -notmatch 'System Volume Information' } | ForEach-Object { Remove-Item -Path `$_.FullName -Recurse -Force -ErrorAction SilentlyContinue }"

    try {
        $result = & ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=empty.txt -o StrictHostKeyChecking=no $NodeName $removeCommand

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully cleaned D: drive on $NodeName"
        } else {
            Write-Host "Failed to clean D: drive on $NodeName"
        }
    } catch {
        Write-Error "An error occurred while cleaning the D: drive on $NodeName. Error: $_"
    }
}

function Invoke-PXEBoot {
    param (
        [string]$local_script,
        [string]$GitHash,
        [string]$WorkerPool,
        [string]$NodeName
    )

    function Run-SSHScript {
        param (
            [string]$Command,
            [string]$NodeName,
            [ref]$ExitCodeVariable
        )

        ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=empty.txt -o StrictHostKeyChecking=no $NodeName "powershell -file $command"
    }

    function Invoke-SSHCommand {
        param (
            [string]$Command,
            [string]$NodeName
        )

        $sshOutput = & ssh $NodeName $Command
        $exitCode = $LASTEXITCODE
        return @{ ExitCode = $exitCode; Output = $sshOutput }
    }

    function Run-SSHCommand {
        param (
            [string]$Command,
            [string]$NodeName
        )
        ssh -q -o ConnectTimeout=5 -o UserKnownHostsFile=empty.txt -o StrictHostKeyChecking=no $NodeName $command
    }

    function Set-LocalPXE {
        param ()

        Write-Host "Local force PXE not found. Creating one."
        $localscript = "SetPXE.ps1"
        $remoteScriptPath = "C:\SetPXE.ps1"
        $remoteScriptlocation = $NodeName + ":" + $remoteScriptPath

        if (!(Test-Path $localscript)) {
            Set-Content -Path $localscript -Value $content
        }
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=empty.txt $localscript $remoteScriptlocation

        Run-SSHScript -Command $remoteScriptPath -NodeName $NodeName
        $script:PXEcounter++
    }

    $pxereboot = "$local_script"

    try {
        $result = Run-SSHScript -Command $script:local_script -NodeName $NodeName
        switch ($LASTEXITCODE) {
            0 {
                if ($result  -like "*success*") {
                    Write-Host "Force PXE script completed successfully."
                } else {
                    Write-Host Remote scripts failed!!!
                    $script:failed_script += "$node_name"
                    Set-LocalPXE
                }
            }
            255 {
                Write-Host "SSH connection failed."
                $script:failed_ssh += "$node_name"
            }
            Default {
                $script:failed_script += "$node_name"
                Set-LocalPXE
            }
        }
    } catch {
        Write-Error "An error occurred while running the PXE script: $_"
        $script:failed_script  += $node_name
        write-host LOOK! $script:failed_script
        Set-LocalPXE
    }
    write-host
    if (($localscript)-and (Test-Path $localscript)) {
        Remove-Item -path $localscript
    }
    if ((Test-Path empty.txt)) {
        Remove-Item -path empty.txt
    }
}

if ($help) {
    Write-Host @"
Usage: script.ps1 [options]

Options:
  -single       	: Operate on a single node.
  -node         	: Specify the node name when using the -single option.
  -range        	: Operate on a range of nodes. Requires hw_class, start, and end parameters.
  -listHwClass  	: List all available hardware classes.
  -pool         	: Operate on an entire pool of nodes. Followed by pool name.
  -pool_name        : Specify the pool name when using the -pool option.
  -cleanDDrive      : Remove D drive contents and force resync of OS installation files.
  -keepOSfiles      : Keep D drive contents.
  -help         	: Display this help message.

  To use this script you will need:
    1. The Win Audit SSH key (available in relops 1 password).
    2. The following in your SSH config file:

        Host nuc*.wintest2.releng.mdc1.mozilla.com
        User administrator
        IdentityFile ~/.ssh/win_audit_id_rsa
"@
    exit
}

Write-Host "Pulling pool data from $yaml_url"
$YAML = Invoke-WebRequest -Uri $yaml_url | ConvertFrom-YAML

if ($listHwClass) {
    Write-Host "Available hardware classes:"
    foreach ($hw in $YAML.validate.hw_class) {
        Write-Host "- $hw"
    }
    exit
}

if ($single) {
    if (-not [string]::IsNullOrWhiteSpace($node)) {
        Write-Host "Single parameter is present. Node value is: $node"
    }
    else {
        Write-Host "Error: Single parameter requires a non-empty value."
        $node = Read-Host "Enter a value for 'node'"
        if ([string]::IsNullOrWhiteSpace($node)) {
            Write-Host "No value provided for 'node'. Exiting script."
            exit
        }
    }
    if ((-not $cleanDDrive) -and (-not $keepOSfiles)) {
        $cleanD = Read-Host "Clean D Drive? 'y' or 'n'"
        switch ($cleanD) {
            'y' {
                $cleanDDrive = $true
                Write-Host "Removing D drive contents."
            }
            'n' {
                Write-Host "Drive D will not be touched."
            }
            default {
                Write-Host "Drive D will not be touched."
            }
        }
    }
    $node_name = $node + "." + $domain_suffix
    foreach ($worker_pool in $YAML.pools) {
        foreach ($worker in $worker_pool.nodes) {
            if ($worker -match $worker_node_name) {
                $WorkerPool = $worker_pool.name
                $hash = $worker_pool.hash
                $image_name = $worker_pool.image
                break
            } else {
                Write-Host "Node name not found!!"
                exit 96
            }
        }
    }
    Write-Host Connecting to $node_name
    if ($cleanDDrive) {
        Write-Host Remove D drive contents
        Clean-DDrive -NodeName $node_name
    }
    Invoke-PXEBoot -AuditScript -NodeName $node_name
}

if ($range) {
    if ((-not [string]::IsNullOrWhiteSpace($start)) -or ((-not [string]::IsNullOrWhiteSpace($end)))) {
        Write-Host "Single parameter is present. Node value is: $node"
    } else {
        Write-Host "Error: hw class parameter requires a non-empty value."
        $hw_class = Read-Host "Enter hw class'"
        if ([string]::IsNullOrWhiteSpace($hw_class)) {
            Write-Host "No value provided for 'hw class'. Exiting script."
            exit
        }
        if (!($YAML.validate.hw_class -contains $hw_class)) {
            Write-Host "Value provided for 'hw class' is not valid. Exiting script."
            exit
        }
        Write-Host "Error: Start parameter requires a non-empty value."
        $start = Read-Host "Enter starting node'"
        if ([string]::IsNullOrWhiteSpace($start)) {
            Write-Host "No value provided for 'start'. Exiting script."
            exit
        }
        Write-Host "Error: End parameter requires a non-empty value."
        $end = Read-Host "Enter ending node'"
        if ([string]::IsNullOrWhiteSpace($end)) {
            Write-Host "No value provided for 'end'. Exiting script."
            exit
        }
    }
    if ((-not $cleanDDrive) -and (-not $keepOSfiles)) {
        $cleanD = Read-Host "Clean D Drive? 'y' or 'n'"
        switch ($cleanD) {
            'y' {
                $cleanDDrive = $true
                Write-Host "Removing D drive contents."
            }
            'n' {
                Write-Host "Drive D will not be touched."
            }
            default {
                Write-Host "Drive D will not be touched."
            }
        }
    }

    $startInt = [int]$start
    $endInt = [int]$end
    $counter = 0

    for ($i = $startInt; $i -le $endInt; $i++) {
        $formattedNumber = "{0:D3}" -f $i
        $node_name = $hw_class + "-" + $formattedNumber + "." + $domain_suffix
        Write-Host Connecting to $node_name

        Write-Host Connecting to $node_name
        if ($cleanDDrive) {
            Write-Host Remove D drive contents
            Clean-DDrive -NodeName $node_name
        }
        Invoke-PXEBoot -AuditScript -NodeName $node_name

        Write-Host "Nodes with script issues:"
        foreach ($node in $script:failed_script) {
            Write-Host "- $node"
        }
        Write-Host "Nodes with failed SSH connection:"
        foreach ($node in $script:failed_ssh) {
            Write-Host "- $node"
        }

        if ($script:failed_ssh.Length -gt 0) {
            Write-host Waiting then will retry nodes with failed SSH connection
            start-sleep -s 600
            $script:wrong_config  = @()
            $script:failed_script  = @()
            $1failed_ssh = $script:failed_ssh
            $script:failed_ssh = @()

            foreach ($node in $1failed_ssh) {
                Write-Host Connecting to $node_name
                if ($cleanDDrive) {
                    Write-Host Remove D drive contents
                    Clean-DDrive -NodeName $node_name
                }
                Invoke-PXEBoot -AuditScript -NodeName $node_name
            }
        }
    }
}

if ($pool) {
    if (-not [string]::IsNullOrWhiteSpace($pool_name)) {
        Write-Host "Single parameter is present. Pool value is: $pool_name"
    }
    else {
        Write-Host "Error: Pool name parameter requires a non-empty value."
        Write-Host "Pool values can be:"
        $pool_array = @()
        foreach ($worker_pool in $YAML.pools) {
            Write-Host $worker_pool.name
            Write-Host Description: $worker_pool.Description
            write-host
        }
        $pool_name = Read-Host "Enter pool name:'"
        if ([string]::IsNullOrWhiteSpace($pool_name)) {
            Write-Host "No value provided for 'pool name'. Exiting script."
            exit
        }
    }
    if ((-not $cleanDDrive) -and (-not $keepOSfiles)) {
        $cleanD = Read-Host "Clean D Drive? 'y' or 'n'"
        switch ($cleanD) {
            'y' {
                $cleanDDrive = $true
                Write-Host "Removing D drive contents."
            }
            'n' {
                Write-Host "Drive D will not be touched."
            }
            default {
                Write-Host "Drive D will not be touched."
            }
        }
    }
    $pool_array = @()
    foreach ($worker_pool in $YAML.pools) {
        $pool_array += $worker_pool.name
    }
    if ($pool_array -notcontains $pool_name) {
        Write-Host "$pool_name is not valid pool name. Exiting script."
        exit
    }

    $nodes = ($YAML.pools | Where-Object { $_.name -eq $pool_name }).nodes
    $hash  = ($YAML.pools | Where-Object { $_.name -eq $pool_name }).hash
    $image_name  = ($YAML.pools | Where-Object { $_.name -eq $pool_name }).image

	$script:PXEcounter = 0
    foreach ($node in $nodes) {
        $node_name = $node + "." + $worker_pool.domain_suffix
        Write-Host Connecting to $node_name
        if ($cleanDDrive) {
            Write-Host Remove D drive contents
            Clean-DDrive -NodeName $node_name
        }
        Invoke-PXEBoot -AuditScript -NodeName $node_name
        if ($script:PXEcounter % 10 -eq 0) {
            Write-Host "Waiting one minute before continuing. Allowing connections to file server to close"
            Start-Sleep -s 60
        }
    }

    Write-Host "Nodes with script issues:"
    foreach ($node in $script:failed_script) {
        Write-Host "- $node"
    }
    Write-Host "Nodes with failed SSH connection:"
    foreach ($node in $script:failed_ssh) {
        Write-Host "- $node"
    }

    if ($script:failed_ssh.Length -gt 0) {
        Write-host Waiting then will retry nodes with failed SSH connection
        start-sleep -s 600
        $script:wrong_config  = @()
        $script:failed_script  = @()
        $1failed_ssh = $script:failed_ssh
        $script:failed_ssh = @()

        foreach ($node in $1failed_ssh) {
            Write-Host Connecting to $node_name
            if ($cleanDDrive) {
                Write-Host Remove D drive contents
                Clean-DDrive -NodeName $node_name
            }
            Invoke-PXEBoot -AuditScript -NodeName $node_name
        }
    }
}
