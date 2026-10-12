# Pester loads this file before each test file in this directory.
$windowsSetup = {
    $ErrorActionPreference = 'Stop'
    $Role = $env:PUPPET_ROLE
    $env:FACTER_custom_win_role = $Role

    function Get-HieraValue {
        param([string[]]$Keys, [string]$Default)
        $options = @()
        if ($PSBoundParameters.ContainsKey('Default')) { $options += @('--default', $Default) }
        $value = & "$env:ProgramFiles\Puppet Labs\Puppet\bin\puppet.bat" lookup @Keys @options `
            --hiera_config C:/ronin_puppet/hiera.yaml --render-as json
        if ($LASTEXITCODE -ne 0) { throw "Hiera lookup failed for $($Keys -join ', ') (exit $LASTEXITCODE)." }
        $value | ConvertFrom-Json
    }

    $Tester = (Get-HieraValue 'win-worker.function') -eq 'tester'
    $Arm = $Role -like '*a64*'
    $Server = $Role -like 'win202*'
    $Win10 = $Role -eq 'win10642009azure'
    $Win25 = $Role -eq 'win116425h2azure'
    $Server25 = $Role -eq 'win20256424h2azure'
    $TaskDrive = Get-HieraValue 'windows_task_drive' -Default 'D:'
    $Ronin = 'C:\ProgramData\PuppetLabs\ronin'
    $DxSdk = 'C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)'
}

BeforeDiscovery $windowsSetup
BeforeAll $windowsSetup
