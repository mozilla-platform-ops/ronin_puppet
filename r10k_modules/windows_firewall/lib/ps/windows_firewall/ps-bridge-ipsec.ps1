param(
    [String] $Target,
    [String] $Name,
    [String] $DisplayName,
    [String] $Description,
    $Enabled,
    [String] $Protocol,
    [String] $Mode,
    $Profile,
    [String] $LocalAddress,
    [String] $RemoteAddress,
    [String]    $LocalPort,
    [String]    $RemotePort,
    $InterfaceType,
    $Phase1AuthSet,
    $Phase2AuthSet,
    $InboundSecurity,
    $OutboundSecurity
)

Import-Module NetSecurity

function Convert-IpAddressToMaskLength([string] $Address)
{
  if ($Address -like '*/*') {
  $Network=$Address.Split('/')[0]
  $SubnetMask=$Address.Split('/')[1]
  $result = 0; 
  # ensure we have a valid IP address
  [IPAddress] $ip = $SubnetMask;
  $octets = $ip.IPAddressToString.Split('.');
  foreach($octet in $octets)
  {
    while(0 -ne $octet) 
    {
      $octet = ($octet -shl 1) -band [byte]::MaxValue
      $result++; 
    }
  }
  return $Network+'/'+$result;
  }
  else {
      return $Address;
  }   
}

function show {
    $rules = New-Object System.Collections.ArrayList

    # Firewall IPsecrules query (InstanceID is the unique key)
    $firewallRules = Get-NetIPsecRule | Select-Object InstanceID, Name, DisplayName, Description, Enabled, Profile, DisplayGroup, Mode, InboundSecurity, OutboundSecurity, Phase1AuthSet, Phase2AuthSet
    # Run Firewall rules filter queries only if Firewall IPSec Rules exists (Until both scripts are merged in one single PowerShell script to manage everything)
    if ($firewallRules) {
        # Querying Firewall rules filter in one query (Parsing for each rule is cpu/time consuming)
        $af_rules = Get-NetFirewallAddressFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|ConSecRule|*'} | Select-Object InstanceID, LocalAddress, RemoteAddress
        $pf_rules = Get-NetFirewallPortFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|ConSecRule|*'} | Select-Object InstanceID, LocalPort, RemotePort, Protocol
        $if_rules = Get-NetFirewallInterfaceTypeFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|ConSecRule|*'} | Select-Object InstanceID, InterfaceType
    }

    # Parse all firewall rules (Using foreach to improve performance)
    ForEach ($firewallRule in $firewallRules) {
        ## Parsing using foreach to improve performance
        $InstanceID=$firewallRule.InstanceID
        ForEach ($af_rule in $af_rules) {if ($af_rule.InstanceID -eq $InstanceID) {$af=$af_rule}}
        ForEach ($pf_rule in $pf_rules) {if ($pf_rule.InstanceID -eq $InstanceID) {$pf=$pf_rule}}
        ForEach ($if_rule in $if_rules) {if ($if_rule.InstanceID -eq $InstanceID) {$if=$if_rule}}
        
        # TO BE IMPLEMENTED
        #$Phase1AuthSet = (Get-NetIPsecPhase1AuthSet -AssociatedNetIPsecRule $_)[0]
        #$Phase2AuthSet = (Get-NetIPsecPhase2AuthSet -AssociatedNetIPsecRule $_)[0]

        $rules.Add(@{
                Name                = $firewallRule.Name
                DisplayName         = $firewallRule.DisplayName
                Description         = $firewallRule.Description
                Enabled             = $firewallRule.Enabled.toString()
                Profile             = $firewallRule.Profile.toString()
                DisplayGroup        = $firewallRule.DisplayGroup
                Mode                = $firewallRule.Mode.toString()
                # Address Filter (Newer powershell versions return a hash)
                LocalAddress        = if ($af.LocalAddress -is [object]) { ($af.LocalAddress | ForEach-Object {Convert-IpAddressToMaskLength $_} | Sort-Object) -join ","  } else { Convert-IpAddressToMaskLength $af.LocalAddress }
                RemoteAddress       = if ($af.RemoteAddress -is [object]) { ($af.RemoteAddress | ForEach-Object {Convert-IpAddressToMaskLength $_} | Sort-Object) -join ","  } else { Convert-IpAddressToMaskLength $af.RemoteAddress }
                # Port Filter (Newer powershell versions return a hash)
                LocalPort           = if ($pf.LocalPort -is [object]) { $pf.LocalPort -join "," } else { $pf.LocalPort }
                RemotePort          = if ($pf.RemotePort -is [object]) { $pf.RemotePort -join "," } else { $pf.RemotePort }
                Protocol            = $pf.Protocol
                # Interface Filter
                InterfaceType       = $if.InterfaceType.toString()
                InboundSecurity     = $firewallRule.InboundSecurity.toString()
                OutboundSecurity    = $firewallRule.OutboundSecurity.toString()
                Phase1AuthSet       = $firewallRule.Phase1AuthSet
                Phase2AuthSet       = $firewallRule.Phase2AuthSet
            }) > $null
    }

    convertto-json $rules

}

function create {

    $params = @{
        Name        = $Name;
        Enabled     = $Enabled;
        DisplayName = $DisplayName;
        Description = $Description;
    }

    #
    # general optional params
    #

    if ($Profile) {
        $params.Add("Profile", $Profile)
    }

    #
    # port filter
    #
    if ($Protocol) {
        $params.Add("Protocol", $Protocol)
    }
    if ($Mode) {
        $params.Add("Mode", $Mode)
    }

    # `$LocalPort` and `$RemotePort` will always be strings since we were
    # invoked with `powershell -File`, rather then refactor the loader to use
    # `-Command`, just do a simple string split. The firewall GUI will sort any
    # passed port ranges but the PS API does not
    if ($LocalPort) {
        $params.Add("LocalPort", ($LocalPort -split ','))
    }
    if ($RemotePort) {
        $params.Add("RemotePort", ($RemotePort -split ','))
    }

    #
    # Interface filter
    #
    if ($InterfaceType) {
        $params.Add("InterfaceType", $InterfaceType)
    }

    # Host filter
    if ($LocalAddress) {
        $params.Add("LocalAddress", ($LocalAddress -split ','))
    }
    if ($RemoteAddress) {
        $params.Add("remoteAddress", ($RemoteAddress -split ','))
    }
    if ($InboundSecurity) {
        $params.Add("InboundSecurity", $InboundSecurity)
    }
    if ($OutboundSecurity) {
        $params.Add("OutboundSecurity", $OutboundSecurity)
    }
    #PhaseAuthSet is case sensitive
    if ($Phase1AuthSet -eq 'Computerkerberos') {
        $params.Add("Phase1AuthSet", 'ComputerKerberos')
    }
    elseif ($Phase1AuthSet) {
        $params.Add("Phase1AuthSet", $Phase1AuthSet)
    }
    if ($Phase2AuthSet -eq 'Userkerberos') {
        $params.Add("Phase2AuthSet", 'UserKerberos')
    }
    elseif ($Phase2AuthSet) {
        $params.Add("Phase2AuthSet", $Phase2AuthSet)
    }

    #Create PhaseAuthSet if doesn't exist (Exist by default on GUI but not on CORE)
    if ($Phase1AuthSet -eq 'Computerkerberos') {
        if (!(Get-NetIPsecPhase1AuthSet -Name 'ComputerKerberos' -erroraction 'silentlycontinue')) {
            $mkerbauthprop = New-NetIPsecAuthProposal -Machine -Kerberos
            New-NetIPsecPhase1AuthSet -Name 'ComputerKerberos' -DisplayName 'ComputerKerberos' -Proposal $mkerbauthprop
        }
    }
    elseif ($Phase1AuthSet -eq 'Anonymous') {
        if (!(Get-NetIPsecPhase1AuthSet -Name 'Anonymous' -erroraction 'silentlycontinue')) {
            $anonyauthprop = New-NetIPsecAuthProposal -Anonymous
            New-NetIPsecPhase1AuthSet -Name 'Anonymous' -DisplayName 'Anonymous' -Proposal $anonyauthprop
        }
    }
    if ($Phase2AuthSet -eq 'Userkerberos') {
        #Create Phase1AuthSet if doesn't exist (Exist by default on GUI but not on CORE)
        if (!(Get-NetIPsecPhase2AuthSet -Name 'Userkerberos' -erroraction 'silentlycontinue')) {
            $ukerbauthprop = New-NetIPsecAuthProposal -User -Kerberos
            New-NetIPsecPhase2AuthSet -Name 'Userkerberos' -DisplayName 'Userkerberos' -Proposal $ukerbauthprop
        }
    }

    New-NetIPSecRule @params -ErrorAction Stop
}

function update {
    write-host "Updating $($Name)..."

    # rules containing square brackets need to be escaped or nothing will match
    $Name = $name.replace(']', '`]').replace('[', '`[')

    $params = @{
    }
    if ($DisplayName) {
        $params.Add("NewDisplayName", $DisplayName)
    }
    if ($Enabled) {
        $params.Add("Enabled", $Enabled)
    }
    if ($Description) {
        $params.Add("Description", $Description)
    }
    if ($Action) {
        $params.Add("Action", $Action)
    }
    #
    # general optional params
    #

    if ($Profile) {
        $params.Add("Profile", $Profile)
    }

    #
    # port filter
    #
    if ($Protocol) {
        $params.Add("Protocol", $Protocol)
    }
    if ($Mode) {
        $params.Add("Mode", $Mode)
    }

    # `$LocalPort` and `$RemotePort` will always be strings since we were
    # invoked with `powershell -File`, rather then refactor the loader to use
    # `-Command`, just do a simple string split. The firewall GUI will sort any
    # passed port ranges but the PS API does not
    if ($LocalPort) {
        $params.Add("LocalPort", ($LocalPort -split ','))
    }
    if ($RemotePort) {
        $params.Add("RemotePort", ($RemotePort -split ','))
    }

    #
    # Interface filter
    #
    if ($InterfaceType) {
        $params.Add("InterfaceType", $InterfaceType)
    }

    # Host filter
    if ($LocalAddress) {
        $params.Add("LocalAddress", ($LocalAddress -split ','))
    }
    if ($RemoteAddress) {
        $params.Add("remoteAddress", ($RemoteAddress -split ','))
    }
    if ($InboundSecurity) {
        $params.Add("InboundSecurity", $InboundSecurity)
    }
    if ($OutboundSecurity) {
        $params.Add("OutboundSecurity", $OutboundSecurity)
    }
    #PhaseAuthSet is case sensitive
    if ($Phase1AuthSet -eq 'Computerkerberos') {
        $params.Add("Phase1AuthSet", 'ComputerKerberos')
    }
    elseif ($Phase1AuthSet) {
        $params.Add("Phase1AuthSet", $Phase1AuthSet)
    }
    if ($Phase2AuthSet -eq 'Userkerberos') {
        $params.Add("Phase2AuthSet", 'UserKerberos')
    }
    elseif ($Phase2AuthSet) {
        $params.Add("Phase2AuthSet", $Phase2AuthSet)
    }

    #Create PhaseAuthSet if doesn't exist (Exist by default on GUI but not on CORE)
    if ($Phase1AuthSet -eq 'Computerkerberos') {
        if (!(Get-NetIPsecPhase1AuthSet -Name 'ComputerKerberos' -erroraction 'silentlycontinue')) {
            $mkerbauthprop = New-NetIPsecAuthProposal -Machine -Kerberos
            New-NetIPsecPhase1AuthSet -Name 'ComputerKerberos' -DisplayName 'ComputerKerberos' -Proposal $mkerbauthprop
        }
    }
    elseif ($Phase1AuthSet -eq 'Anonymous') {
        if (!(Get-NetIPsecPhase1AuthSet -Name 'Anonymous' -erroraction 'silentlycontinue')) {
            $anonyauthprop = New-NetIPsecAuthProposal -Anonymous
            New-NetIPsecPhase1AuthSet -Name 'Anonymous' -DisplayName 'Anonymous' -Proposal $anonyauthprop
        }
    }
    if ($Phase2AuthSet -eq 'Userkerberos') {
        #Create Phase1AuthSet if doesn't exist (Exist by default on GUI but not on CORE)
        if (!(Get-NetIPsecPhase2AuthSet -Name 'Userkerberos' -erroraction 'silentlycontinue')) {
            $ukerbauthprop = New-NetIPsecAuthProposal -User -Kerberos
            New-NetIPsecPhase2AuthSet -Name 'Userkerberos' -DisplayName 'Userkerberos' -Proposal $ukerbauthprop
        }
    }

    if (Get-NetIPSecRule -Name $name -erroraction SilentlyContinue) {
        Set-NetIPSecRule -Name $name @params -ErrorAction Stop
    }
    else {
        throw "We were told to update firewall rule '$($name)' but it does not exist"
    }
}

function delete {
    write-host "Deleting $($Name)..."

    # rules containing square brackets need to be escaped or nothing will match
    $Name = $name.replace(']', '`]').replace('[', '`[')

    if (Get-NetIPSecRule -Name $name -ErrorAction SilentlyContinue) {
        Remove-NetIPSecRule -Name $Name -ErrorAction Stop
    }
    else {
        throw "We were told to delete firewall rule '$($name)' but it does not exist"
    }
}

switch ($Target) {
    "show" {
        show
    }
    "delete" {
        delete
    }
    "create" {
        create
    }
    "update" {
        update
    }
    default {
        throw "invalid target: $($Target)"
    }
}