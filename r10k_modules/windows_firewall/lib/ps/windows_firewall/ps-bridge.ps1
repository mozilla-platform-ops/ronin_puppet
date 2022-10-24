param(
    [String] $Target,
    [String] $Name,
    [String] $DisplayName,
    $Enabled,
    $Action,
    [String] $Protocol,
    $IcmpType,
    $Profile,
    [String] $Program,
    $Direction,
    [String] $Description,
    [String] $LocalAddress,
    [String] $RemoteAddress,
    [String] $ProtocolType,
    [Int]    $ProtocolCode,
    [String] $LocalPort,
    [String] $RemotePort,
    $EdgeTraversalPolicy,
    $InterfaceType,
    $Service,
    [String] $Authentication,
    [String] $Encryption,
    [String] $LocalUser,
    [String] $RemoteUser,
    [String] $RemoteMachine
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

# Lookup select firewall rules using powershell.
function Show {
    $rules = New-Object System.Collections.ArrayList

    # Firewall rules query (InstanceID is the unique key)
    $firewallRules = Get-NetFirewallRule | Select-Object InstanceID, Name, DisplayName, Description, Enabled, Action, Direction, EdgeTraversalPolicy, Profile, DisplayGroup
    # Querying Firewall rules filter in one query (Parsing for each rule is cpu/time consuming)
    $af_rules = Get-NetFirewallAddressFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|FirewallRule|*'} | Select-Object InstanceID, LocalAddress, RemoteAddress
    $appf_rules = Get-NetFirewallApplicationFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|FirewallRule|*'} | Select-Object InstanceID, Program
    $pf_rules = Get-NetFirewallPortFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|FirewallRule|*'} | Select-Object InstanceID, LocalPort, RemotePort, Protocol, IcmpType
    $if_rules = Get-NetFirewallInterfaceTypeFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|FirewallRule|*'} | Select-Object InstanceID, InterfaceType
    $sf_rules = Get-NetFirewallServiceFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|FirewallRule|*'} | Select-Object InstanceID, Service
    $secf_rules = Get-NetFirewallSecurityFilter | Where-Object {$_.CreationClassName -like 'MSFT|FW|FirewallRule|*'} | Select-Object InstanceID, Authentication, Encryption, LocalUser, RemoteUser, RemoteMachine

    # Parse all firewall rules (Using foreach to improve performance)
    ForEach ($firewallRule in $firewallRules) {
        ## Parsing using foreach to improve performance
        $InstanceID=$firewallRule.InstanceID
        ForEach ($af_rule in $af_rules) {if ($af_rule.InstanceID -eq $InstanceID) {$af=$af_rule}}
        ForEach ($appf_rule in $appf_rules) {if ($appf_rule.InstanceID -eq $InstanceID) {$appf=$appf_rule}}
        ForEach ($pf_rule in $pf_rules) {if ($pf_rule.InstanceID -eq $InstanceID) {$pf=$pf_rule}}
        ForEach ($if_rule in $if_rules) {if ($if_rule.InstanceID -eq $InstanceID) {$if=$if_rule}}
        ForEach ($sf_rule in $sf_rules) {if ($sf_rule.InstanceID -eq $InstanceID) {$sf=$sf_rule}}
        ForEach ($secf_rule in $secf_rules) {if ($secf_rule.InstanceID -eq $InstanceID) {$secf=$secf_rule}}

        # Creating Rule Hash
        $rules.Add(@{
                Name                = $firewallRule.Name
                DisplayName         = $firewallRule.DisplayName
                Description         = $firewallRule.Description
                Enabled             = $firewallRule.Enabled.toString()
                Action              = $firewallRule.Action.toString()
                Direction           = $firewallRule.Direction.toString()
                EdgeTraversalPolicy = $firewallRule.EdgeTraversalPolicy.toString()
                Profile             = $firewallRule.Profile.toString()
                # If display group is empty, return 'None' (Required for windows_firewall_group)
                DisplayGroup        = if ($null -ne $firewallRule.DisplayGroup) { $firewallRule.DisplayGroup } else { 'None' }
                # Address Filter (Newer powershell versions return a hash)
                LocalAddress        = if ($af.LocalAddress -is [object]) { ($af.LocalAddress | ForEach-Object {Convert-IpAddressToMaskLength $_} | Sort-Object) -join ","  } else { Convert-IpAddressToMaskLength $af.LocalAddress }
                RemoteAddress       = if ($af.RemoteAddress -is [object]) { ($af.RemoteAddress | ForEach-Object {Convert-IpAddressToMaskLength $_} | Sort-Object) -join ","  } else { Convert-IpAddressToMaskLength $af.RemoteAddress }
                # Port Filter (Newer powershell versions return a hash)
                LocalPort           = if ($pf.LocalPort -is [object]) { $pf.LocalPort -join "," } else { $pf.LocalPort }
                RemotePort          = if ($pf.RemotePort -is [object]) { $pf.RemotePort -join "," } else { $pf.RemotePort }
                Protocol            = $pf.Protocol
                IcmpType            = $pf.IcmpType
                # Application Filter
                Program             = $appf.Program
                # Interface Filter
                InterfaceType       = $if.InterfaceType.toString()
                # Service Filter
                Service             = $sf.Service
                # Security Filter
                Authentication      = $secf.Authentication.toString()
                Encryption          = $secf.Encryption.toString()
                LocalUser           = $secf.LocalUser.toString()
                RemoteUser          = $secf.RemoteUser.toString()
                RemoteMachine       = $secf.RemoteMachine.toString()
            }) > $null
    }
    convertto-json $rules
}

function delete {
    write-host "Deleting $Name"

    # rules containing square brackets need to be escaped or nothing will match
    $Name = $name.replace(']', '`]').replace('[', '`[')

    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -Name $Name -ErrorAction Stop
    }
    else {
        throw "We were told to delete firewall rule '$($name)' but it does not exist"
    }
}


function create {
    write-host "Creating $Name"

    $params = @{
        Name        = $Name;
        Enabled     = $Enabled;
        DisplayName = $DisplayName;
        Description = $Description;
        Action      = $Action;
    }

    #
    # general optional params
    #
    if ($Direction) {
        $params.Add("Direction", $Direction)
    }
    if ($EdgeTraversalPolicy) {
        $params.Add("EdgeTraversalPolicy", $EdgeTraversalPolicy)
    }
    if ($Profile) {
        $params.Add("Profile", $Profile)
    }

    #
    # port filter
    #
    if ($Protocol) {
        $params.Add("Protocol", $Protocol)
    }
    if ($ProtocolType) {
        $params.Add("ProtocolType", $ProtocolType)
    }
    if ($ProtocolCode) {
        $params.Add("ProtocolCode", $ProtocolCode)
    }
    if ($IcmpType) {
        $params.Add("IcmpType", $IcmpType)
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
    # Program filter
    #
    if ($Program) {
        $params.Add("Program", $Program)
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

    # Service Filter
    if ($Service) {
        $params.Add("Service", $Service)
    }

    # Security Filter
    if ($Authentication) {
        $params.Add("Authentication", $Authentication)
    }
    if ($Encryption) {
        $params.Add("Encryption", $Encryption)
    }
    if ($LocalUser) {
        $params.Add("LocalUser", $LocalUser)
    }
    if ($RemoteUser) {
        $params.Add("RemoteUser", $RemoteUser)
    }
    if ($RemoteMachine) {
        $params.Add("RemoteMachine", $RemoteMachine)
    }

    New-NetFirewallRule @params -ErrorAction Stop
}

function update {
    write-host "Updating $Name"

    # rules containing square brackets need to be escaped or nothing will match
    $Name = $name.replace(']', '`]').replace('[', '`[')

    $params = @{
        Enabled        = $Enabled;
        NewDisplayName = $DisplayName;
        Description    = $Description;
        Action         = $Action;
    }

    #
    # general optional params
    #
    if ($Direction) {
        $params.Add("Direction", $Direction)
    }
    if ($EdgeTraversalPolicy) {
        $params.Add("EdgeTraversalPolicy", $EdgeTraversalPolicy)
    }
    if ($Profile) {
        $params.Add("Profile", $Profile)
    }

    #
    # port filter
    #
    if ($Protocol) {
        $params.Add("Protocol", $Protocol)
    }
    if ($ProtocolType) {
        $params.Add("ProtocolType", $ProtocolType)
    }
    if ($ProtocolCode) {
        $params.Add("ProtocolCode", $ProtocolCode)
    }
    if ($IcmpType) {
        $params.Add("IcmpType", $IcmpType)
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
    # Program filter
    #
    if ($Program) {
        $params.Add("Program", $Program)
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

    # Service Filter
    if ($Service) {
        $params.Add("Service", $Service)
    }

    # Security Filter
    if ($Authentication) {
        $params.Add("Authentication", $Authentication)
    }
    if ($Encryption) {
        $params.Add("Encryption", $Encryption)
    }
    if ($LocalUser) {
        $params.Add("LocalUser", $LocalUser)
    }
    if ($RemoteUser) {
        $params.Add("RemoteUser", $RemoteUser)
    }
    if ($RemoteMachine) {
        $params.Add("RemoteMachine", $RemoteMachine)
    }

    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) {
        Set-NetFirewallRule -Name $name @params -ErrorAction Stop
    }
    else {
        throw "We were told to update firewall rule '$($name)' but it does not exist"
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
