function Get-InstalledSoftware {
    [CmdletBinding()]
    [OutputType([PSObject])]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$ComputerName = $env:COMPUTERNAME,

        [Switch]$StartRemoteRegistry,
        [Switch]$IncludeLoadedUserHives,
        [Switch]$IncludeBlankNames
    )

    $keys = 'Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    if ($StartRemoteRegistry) {
        $shouldStop = $false
        $service = Get-Service RemoteRegistry -Computer $ComputerName

        if ($service.Status -eq 'Stopped' -and $service.StartType -ne 'Disabled') {
            $shouldStop = $true
            $service | Start-Service
        }
    }

    $baseKeys = [System.Collections.Generic.List[Microsoft.Win32.RegistryKey]]::new()

    $baseKeys.Add([Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $ComputerName, 'Registry64'))
    if ($IncludeLoadedUserHives) {
        try {
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $ComputerName, 'Registry64')
            foreach ($name in $baseKey.GetSubKeyNames()) {
                if (-not $name.EndsWith('_Classes')) {
                    try {
                        $baseKeys.Add($baseKey.OpenSubKey($name, $false))
                    }
                    catch {
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $_.Exception.GetType()::new(
                                ('Unable to access sub key {0} ({1})' -f $name, $_.Exception.InnerException.Message.Trim()),
                                $_.Exception
                            ),
                            'SubkeyAccessError',
                            'InvalidOperation',
                            $name
                        )
                        Write-Error -ErrorRecord $errorRecord
                    }
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }

    foreach ($baseKey in $baseKeys) {
        if ($baseKey.Name -eq 'HKEY_LOCAL_MACHINE') {
            $username = 'LocalMachine'
        }
        else {
            try {
                [System.Security.Principal.SecurityIdentifier]$sid = Split-Path $baseKey.Name -Leaf
                $username = $sid.Translate([System.Security.Principal.NTAccount]).Value
            }
            catch {
                $username = Split-Path $baseKey.Name -Leaf
            }
        }

        foreach ($key in $keys) {
            try {
                $uninstallKey = $baseKey.OpenSubKey($key, $false)

                if ($uninstallKey) {
                    $is64Bit = $key -notmatch 'Wow6432Node'

                    foreach ($name in $uninstallKey.GetSubKeyNames()) {
                        $packageKey = $uninstallKey.OpenSubKey($name)

                        $installDate = Get-Date
                        $dateString = $packageKey.GetValue('InstallDate')
                        if (-not $dateString -or -not [DateTime]::TryParseExact($dateString, 'yyyyMMdd', (Get-Culture), 'None', [Ref]$installDate)) {
                            $installDate = $null
                        }

                        $software = [PSCustomObject]@{
                            Name            = $name
                            DisplayName     = $packageKey.GetValue('DisplayName')
                            DisplayVersion  = $packageKey.GetValue('DisplayVersion')
                            InstallDate     = $installDate
                            InstallLocation = $packageKey.GetValue('InstallLocation')
                            HelpLink        = $packageKey.GetValue('HelpLink')
                            Publisher       = $packageKey.GetValue('Publisher')
                            UninstallString = $packageKey.GetValue('UninstallString')
                            URLInfoAbout    = $packageKey.GetValue('URLInfoAbout')
                            Is64Bit         = $is64Bit
                            Hive            = $baseKey.Name
                            Path            = Join-Path $key $name
                            Username        = $username
                            ComputerName    = $ComputerName
                        }

                        if ($IncludeBlankNames -or $software.DisplayName) {
                            $software
                        }
                    }
                }
            }
            catch {
                Write-Error -ErrorRecord $_
            }
        }
    }

    if ($StartRemoteRegistry -and $shouldStop) {
        $service | Stop-Service
    }
}

function Get-OSVersionExtended {
    [CmdletBinding()]
    param ()

    Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
}

function Get-WinFactsCustomOS {
    $releaseKey = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $releaseId = $releaseKey.ReleaseId
    $caption = ((Get-WmiObject Win32_OperatingSystem).Caption).ToLower() -replace ' ', '_'
    $status = (Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name like 'Windows%'" | Where-Object PartialProductKey).LicenseStatus

    if ($status -eq '1') {
        $kmsStatus = 'activated'
    }
    else {
        $kmsStatus = 'needs_activation'
    }

    $administratorInfo = Get-WmiObject win32_useraccount -Filter "name = 'Administrator'"
    $winAdminSid = $administratorInfo.SID

    $netCategory = Get-NetConnectionProfile | Select-Object -ExpandProperty NetworkCategory
    if ($netCategory -like '*Private*') {
        $networkCategory = 'private'
    }
    else {
        $networkCategory = 'other'
    }

    $firewallStatus = netsh advfirewall show domain state
    if ($firewallStatus -like '*off*') {
        $firewallStatus = 'off'
    }
    else {
        $firewallStatus = 'running'
    }

    $role = (Get-ItemProperty 'HKLM:\SOFTWARE\Mozilla\ronin_puppet').role
    $workerPoolId = (Get-ItemProperty 'HKLM:\SOFTWARE\Mozilla\ronin_puppet').worker_pool_id

    if ($workerPoolId -like '*gpu*') {
        $gpu = 'yes'
    }
    else {
        $gpu = 'no'
    }

    if ($caption -like '*windows_10*') {
        $osVersion = "win_10_$releaseId"
    }
    elseif ($caption -like '*windows_11*') {
        $osVersion = "win_11_$releaseId"
    }
    elseif ($caption -like '*2012*') {
        $osVersion = 'win_2012'
    }
    elseif ($caption -like '*2022*') {
        $osVersion = "win_2022_$releaseId"
    }
    else {
        $osVersion = $null
    }

    if ($role -like '*builder*') {
        $purpose = 'builder'
    }
    elseif ($role -like '*tester*') {
        $purpose = 'tester'
    }
    elseif ($caption -like '*windows_10*' -or $caption -like '*windows_11*') {
        $purpose = 'tester'
    }
    elseif ($caption -like '*2012*' -or $caption -like '*2022*') {
        $purpose = 'builder'
    }
    else {
        $purpose = $null
    }

    $osArch = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
    if ($osArch -like '*ARM*') {
        $arch = 'aarch64'
    }
    else {
        $arch = 'x64'
    }

    [PSCustomObject]@{
        custom_win_release_id      = $releaseId
        custom_win_os_caption      = $caption
        custom_win_os_version      = $osVersion
        custom_win_kms_activated   = $kmsStatus
        custom_win_admin_sid       = $winAdminSid
        custom_win_net_category    = $networkCategory
        custom_win_firewall_status = $firewallStatus
        custom_win_role            = $role
        custom_win_worker_pool_id  = $workerPoolId
        custom_win_gpu             = $gpu
        custom_win_purpose         = $purpose
        custom_win_os_arch         = $arch
    }
}

function Assert-IsBuilder {
    $customOS = Get-WinFactsCustomOS
    switch ($customOS.custom_win_purpose) {
        'builder' { $true }
        default { $false }
    }
}

function Assert-IsTester {
    $customOS = Get-WinFactsCustomOS
    switch ($customOS.custom_win_purpose) {
        'tester' { $true }
        default { $false }
    }
}

function Show-Win11Sdk {
    $names = @(
        'Application Verifier x64 External Package (DesktopEditions)',
        'Application Verifier x64 External Package (OnecoreUAP)',
        'Kits Configuration Installer',
        'MSI Development Tools',
        'SDK ARM Additions',
        'SDK ARM Redistributables',
        'SDK Debuggers',
        'Universal CRT Extension SDK',
        'Universal CRT Headers Libraries and Sources',
        'Universal CRT Redistributable',
        'Universal CRT Tools x64',
        'Universal CRT Tools x86',
        'Universal General MIDI DLS Extension SDK',
        'WinAppDeploy',
        'Windows App Certification Kit Native Components',
        'Windows App Certification Kit SupportedApiList x86',
        'Windows App Certification Kit x64',
        'Windows App Certification Kit x64 (OnecoreUAP)',
        'Windows Desktop Extension SDK',
        'Windows Desktop Extension SDK Contracts',
        'Windows IoT Extension SDK',
        'Windows IoT Extension SDK Contracts',
        'Windows IP Over USB',
        'Windows Mobile Extension SDK',
        'Windows Mobile Extension SDK Contracts',
        'Windows SDK',
        'Windows SDK ARM Desktop Tools',
        'Windows SDK Desktop Headers arm',
        'Windows SDK Desktop Headers arm64',
        'Windows SDK Desktop Headers x64',
        'Windows SDK Desktop Headers x86',
        'Windows SDK Desktop Libs arm',
        'Windows SDK Desktop Libs arm64',
        'Windows SDK Desktop Libs x64',
        'Windows SDK Desktop Libs x86',
        'Windows SDK Desktop Tools arm64',
        'Windows SDK Desktop Tools x64',
        'Windows SDK Desktop Tools x86',
        'Windows SDK DirectX x64 Remote',
        'Windows SDK DirectX x86 Remote',
        'Windows SDK EULA',
        'Windows SDK Facade Windows WinMD Versioned',
        'Windows SDK for Windows Store Apps',
        'Windows SDK for Windows Store Apps Contracts',
        'Windows SDK for Windows Store Apps DirectX x86 Remote',
        'Windows SDK for Windows Store Apps Headers',
        'Windows SDK for Windows Store Apps Libs',
        'Windows SDK for Windows Store Apps Metadata',
        'Windows SDK for Windows Store Apps Tools',
        'Windows SDK for Windows Store Managed Apps Libs',
        'Windows SDK Modern Non-Versioned Developer Tools',
        'Windows SDK Modern Versioned Developer Tools',
        'Windows SDK Redistributables',
        'Windows SDK Signing Tools',
        'Windows Team Extension SDK',
        'Windows Team Extension SDK Contracts',
        'WinRT Intellisense Desktop - en-us',
        'WinRT Intellisense Desktop - Other Languages',
        'WinRT Intellisense IoT - en-us',
        'WinRT Intellisense IoT - Other Languages',
        'WinRT Intellisense Mobile - en-us',
        'WinRT Intellisense PPI - en-us',
        'WinRT Intellisense PPI - Other Languages',
        'WinRT Intellisense UAP - en-us',
        'WinRT Intellisense UAP - Other Languages',
        'WPT Redistributables',
        'WPTx64 (DesktopEditions)',
        'WPTx64 (OnecoreUAP)'
    )

    Get-InstalledSoftware | Where-Object {
        $PSItem.DisplayName -in $names
    }
}

Export-ModuleMember -Function @(
    'Assert-IsBuilder',
    'Assert-IsTester',
    'Get-InstalledSoftware',
    'Get-OSVersionExtended',
    'Get-WinFactsCustomOS',
    'Show-Win11Sdk'
)
