BeforeDiscovery {
    . "$env:systemdrive\ronin\test\integration\windows11\Get-InstalledSoftware.ps1"
}

BeforeDiscovery {
    $Names = @(
        "Application Verifier x64 External Package",
        "Kits Configuration Installer",
        "MSI Development Tools",
        "SDK ARM Additions",
        "SDK ARM Redistributables",
        "SDK Debuggers",
        "Universal CRT Extension SDK",
        "Universal CRT Headers Libraries and Sources",
        "Universal CRT Redistributable",
        "Universal CRT Tools x64",
        "Universal CRT Tools x86",
        "Universal General MIDI DLS Extension SDK",
        "WinAppDeploy",
        "Windows App Certification Kit Native Components",
        "Windows App Certification Kit SupportedApiList x86",
        "Windows App Certification Kit x64",
        "Windows Desktop Extension SDK",
        "Windows Desktop Extension SDK Contracts",
        "Windows IoT Extension SDK",
        "Windows IoT Extension SDK Contracts",
        "Windows IP Over USB",
        "Windows Mobile Extension SDK",
        "Windows Mobile Extension SDK Contracts",
        "Windows SDK",
        "Windows SDK ARM Desktop Tools",
        "Windows SDK Desktop Headers arm",
        "Windows SDK Desktop Headers arm64",
        "Windows SDK Desktop Headers x64",
        "Windows SDK Desktop Headers x86",
        "Windows SDK Desktop Libs arm",
        "Windows SDK Desktop Libs arm64",
        "Windows SDK Desktop Libs x64",
        "Windows SDK Desktop Libs x86",
        "Windows SDK Desktop Tools arm64",
        "Windows SDK Desktop Tools x64",
        "Windows SDK Desktop Tools x86",
        "Windows SDK DirectX x64 Remote",
        "Windows SDK DirectX x86 Remote",
        "Windows SDK EULA",
        "Windows SDK Facade Windows WinMD Versioned",
        "Windows SDK for Windows Store Apps",
        "Windows SDK for Windows Store Apps Contracts",
        "Windows SDK for Windows Store Apps DirectX x86 Remote",
        "Windows SDK for Windows Store Apps Headers",
        "Windows SDK for Windows Store Apps Libs",
        "Windows SDK for Windows Store Apps Metadata",
        "Windows SDK for Windows Store Apps Tools",
        "Windows SDK for Windows Store Managed Apps Libs",
        "Windows SDK Modern Non-Versioned Developer Tools",
        "Windows SDK Modern Versioned Developer Tools",
        "Windows SDK Redistributables",
        "Windows SDK Signing Tools",
        "Windows Team Extension SDK",
        "Windows Team Extension SDK Contracts",
        "WinRT Intellisense Desktop - en-us",
        "WinRT Intellisense Desktop - Other Languages",
        "WinRT Intellisense IoT - en-us",
        "WinRT Intellisense IoT - Other Languages",
        "WinRT Intellisense Mobile - en-us",
        "WinRT Intellisense PPI - en-us",
        "WinRT Intellisense PPI - Other Languages",
        "WinRT Intellisense UAP - en-us",
        "WinRT Intellisense UAP - Other Languages",
        "WPT Redistributables",
        "WPTx64"
    )
    $win10_sdk_2004 = Get-InstalledSoftware | Where-Object {
        $PSItem.DisplayName -in $Names
    }
    $dotnet48 = Get-InstalledSoftware | Where-Object {
        $PSItem.DisplayName -like "Microsoft .NET Framework 4.8*"
    }
    $vcc2019 = Get-InstalledSoftware | Where-Object {
        $PSItem.DisplayName -like "Microsoft Visual C++ 2019*"
    }
    $sdkaddon = Get-InstalledSoftware | Where-Object {
        $PSItem.DisplayName -eq "Windows SDK AddOn"
    }
}

Describe "Microsoft Tools" {
    It "<_.DisplayName> is installed" -ForEach @(
        $win10_sdk_2004
    ) {
        $PSItem.DisplayName -in $Names | Should -Not -Be $null
    }
    It "<_.DisplayName> is 10.1.19041.685" -ForEach @(
        $win10_sdk_2004
    ) {
        $PSItem.DisplayVersion | Should -Be "10.1.19041.685"
    }
    It "<_.DisplayName> is installed" -ForEach @(
        $dotnet48
    ) {
        $_.DisplayName | Should -Not -Be $Null
    }
    It "<_.DisplayName> is version 4.8.04084" -ForEach @(
        $dotnet48
    ) {
        $_.DisplayVersion | Should -Be "4.8.04084"
    }
    It "<_.DisplayName> is installed" -ForEach @(
        $vcc2019
    ) {
        $_.DisplayName | Should -Not -Be $Null
    }
    It "<_.DisplayName> is version 14.29.30139" -ForEach @(
        $vcc2019
    ) {
        $_.DisplayVersion | Should -Be "14.29.30139"
    }
    It "<_.DisplayName> is installed" -ForEach @(
        $sdkaddon
    ) { 
        $_.DisplayName |  Should -Not -Be $Null
    }
    It "<_.DisplayName> is version 10.1.0.0" -ForEach @(
        $sdkaddon
    ) {
        $_.DisplayVersion | Should -Be 10.1.0.0
    }
}