![Build Status](https://ci.appveyor.com/api/projects/status/github/GeoffWilliams/puppet-windows_firewall?svg=true)
# windows_firewall

#### Table of Contents

1. [Description](#description)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

Manage the windows firewall with Puppet (PowerShell as required).

## Features
* Create/edit/delete individual firewall rules (`windows_firewall_rule`)
* Create/edit/delete individual firewall ipsec rules (`windows_firewall_ipsec_rule`)
* Enable/disable firewall groups (`windows_firewall_group`)
* Adjust global settings (`windows_firewall_global`)
* Adjust per-profile settings (`windows_firewall_profile`)

## Usage

### windows_firewall_rule
Manage individual firewall rules

#### Listing firewall rules

The type and provider is able to enumerate the firewall rules existing on the 
system:

```shell
C:\>puppet resource windows_firewall_rule
...
windows_firewall_rule { '{FCC26AEB-5C68-481A-96DA-8A404F73714C}':
  ensure                => 'present',
  action                => 'allow',
  description           => 'Mail and Calendar',
  direction             => 'inbound',
  display_group         => 'Mail and Calendar',
  display_name          => 'Mail and Calendar',
  edge_traversal_policy => 'allow',
  enabled               => 'true',
  icmp_type             => 'any',
  interface_type        => ['any'],
  local_address         => 'any',
  local_port            => 'any',
  profile               => ['domain', 'private', 'public'],
  program               => 'Any',
  protocol              => 'any',
  remote_address        => 'any',
  remote_port           => 'any',
}
```

You can limit output to a single rule by passing its name as an argument, eg:

```shell
C:\>puppet resource windows_firewall_rule winrm
windows_firewall_rule { 'winrm':
  ensure                => 'present',
  action                => 'allow',
  direction             => 'inbound',
  display_name          => 'winrm',
  edge_traversal_policy => 'block',
  enabled               => 'true',
  interface_type        => ['any'],
  local_address         => 'any',
  local_port            => '5985',
  profile               => ['domain', 'private', 'public'],
  protocol              => 'tcp',
  remote_address        => 'any',
  remote_port           => 'any',
}
```

#### Ensuring a rule

The basic syntax for ensuring rules is: 

```puppet
windows_firewall_rule { "name of rule":
  ensure => present,
  ...
}
```

If a rule with the same name but different properties already exists, it will be
deleted and re-created to ensure it is defined correctly. To delete a rule, set
`ensure => absent`.

#### Managing ICMP
```puppet
windows_firewall_rule { "puppet - all icmpv4":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  protocol  => "icmpv4",
}
```

You can also create a rule that only allows a specific ICMP type and code:
```puppet
windows_firewall_rule { "puppet - allow icmp echo":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  protocol  => "icmpv4",
  icmp_type => "8:10",
}
```
You need to create one rule for each `icmp_type` value (see limitations).

#### Managing Ports

Use the `local_port` and `remote_port` properties to set the ports a rule refers
to. You can set an individual ports, a range or combination:

```puppet
windows_firewall_rule { "puppet - allow ports 1000-2000":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "80,443,4243,5000-5010",
}

```

#### Managing Programs

```puppet
windows_firewall_rule { "puppet - allow messenger":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  program   => "C:\\programfiles\\messenger\\msnmsgr.exe",
}
```

#### Creating rules in specific profiles
```puppet
windows_firewall_rule { "puppet - open port in specific profiles":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  profile    => ["private", "domain"],
  local_port => "666",
}
```

#### Manage authentication
```puppet
windows_firewall_rule { "puppet - open port in specific profiles":
  ensure           => present,
  direction        => "inbound",
  action           => "allow",
  protocol         => "tcp",
  profile          => ["private", "domain"],
  local_port       => "666",
  authentication   => "required",
  local_user       => {'allow' => 'contoso\\group1,contoso\\group2'},
  remote_machine   => {'allow' => 'contoso\\group1,contoso\\group2'}
}
```
#### Manage encryption
```puppet
windows_firewall_rule { "puppet - open port in specific profiles":
  ensure         => present,
  direction      => "inbound",
  action         => "allow",
  protocol       => "tcp",
  profile        => ["private", "domain"],
  local_port     => "666",
  authentication => "required",
  encryption     => "required",
  local_user     => {'allow' => 'contoso\\group1',
                     'block' => 'contoso\\group2'},
  remote_user    => {'allow' => 'contoso\\group1',
                     'block' => 'contoso\\group2'},
  remote_machine => {'allow' => 'contoso\\group1',
                     'block' => 'contoso\\group2'}
}
```

#### Purging rules

You can choose to purge unmanaged rules from the system (be careful! - this will
remove _any_ rule that is not manged by Puppet including those created by 
Windows itself):

```puppet
resources { "windows_firewall_rule":
  purge => true,
}

windows_firewall_rule { "puppet - allow all":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "any",
}
```

### windows_firewall_ipsec_rule
Manage individual ipsec rules (Connection Security rules)

windows_firewall_ipsec_rule { 'test - ipsec':
  ensure            => present,
  local_port        => '9999,1900',
  local_address     => $::ipaddress,
  remote_address    => '192.168.0.0/24,192.168.1.0/24',
  protocol          => 'tcp',
  inbound_security  => 'require',
  outbound_security => 'require',
  phase1auth_set    => 'computerkerberos',
  phase2auth_set    => 'userkerberos'
}

#### Listing ipsec firewall rules

The type and provider is able to enumerate the firewall rules existing on the 
system:

```shell
C:\>puppet resource windows_firewall_ipsec_rule
...
#WIP
```

You can limit output to a single rule by passing its name as an argument, eg:

```shell
C:\>puppet resource windows_firewall_ipsec_rule winrm
#WIP
```

#### Ensuring a rule

The basic syntax for ensuring rules is: 

```puppet
windows_firewall_ipsec_rule { "name of rule":
  ensure => present,
  ...
}
```

If a rule with the same name but different properties already exists, it will be
deleted and re-created to ensure it is defined correctly. To delete a rule, set
`ensure => absent`.

#WIP

#### Purging rules

You can choose to purge unmanaged rules from the system (be careful! - this will
remove _any_ rule that is not manged by Puppet including those created by 
Windows itself):

```puppet
resources { "windows_firewall_ipsec_rule":
  purge => true,
}

```

### windows_firewall_group
Enable/Disable named groups of firewall rules. Not that it is only possible to
enable/disable existing groups, not create or edit them.

#### Enabling a group of rules

```puppet
windows_firewall_group { "File and Printer Sharing":
  enabled => true,
}
```

#### Disabling a group of rules

```puppet
windows_firewall_group { "File and Printer Sharing":
  enabled => false,
}
```

### windows_firewall_global
Global settings always exist (there is no `ensure`). 

#### Displaying settings
You can use `puppet resource windows_firewall_global` to check what Puppet 
thinks the current values are:

```shell
C:\vagrant>puppet resource windows_firewall_global
windows_firewall_global { 'global':
  authzcomputergrp          => 'none',
  authzcomputergrptransport => 'none',
  authzusergrp              => 'none',
  authzusergrptransport     => 'none',
  boottimerulecategory      => 'windows firewall',
  consecrulecategory        => 'windows firewall',
  defaultexemptions         => ['dhcp', 'neighbordiscovery'],
  firewallrulecategory      => 'windows firewall',
  forcedh                   => 'yes',
  ipsecthroughnat           => 'serverbehindnat',
  keylifetime               => '485min,0sess',
  saidletimemin             => '6',
  secmethods                => 'dhgroup2:aes128-sha1,dhgroup2:3des-sha1',
  statefulftp               => 'disable',
  statefulpptp              => 'disable',
  stealthrulecategory       => 'windows firewall',
  strongcrlcheck            => '1',
}
```

Note: some properties are read-only.

#### Managing global settings

A single resource with an arbitrary title should be used to manage the desired
settings, eg:

```puppet
windows_firewall_global { 'global':
  authzcomputergrp          => 'none',
  authzusergrp              => 'none',
  defaultexemptions         => ['neighbordiscovery','dhcp'],
  forcedh                   => 'yes',
  ipsecthroughnat           => 'serverbehindnat',
  keylifetime               => '485min,0sess',
  saidletimemin             => '6',
  secmethods                => 'dhgroup2:aes128-sha1,dhgroup2:3des-sha1',
  statefulftp               => 'disable',
  statefulpptp              => 'disable',
  strongcrlcheck            => '1',
}
```

### windows_firewall_profile

There are three firewall profiles that the module supports:

* private
* domain
* public

Depending on the network the node is connected to, one of these profiles will be
active. They map to three Puppet resources which cannot be _ensured_:

* `Windows_firewall_profile[private]`
* `Windows_firewall_profile[domain]`
* `Windows_firewall_profile[public]`

#### Displaying settings

Use `puppet resource windows_firewall_profile` to see what puppet thinks the 
settings are:

```shell
C:\vagrant>puppet resource windows_firewall_profile
windows_firewall_profile { 'domain':
  filename                   => '%systemroot%\system32\logfiles\firewall\pfirewall.log',
  firewallpolicy             => 'blockinbound,allowoutbound',
  inboundusernotification    => 'disable',
  localconsecrules           => 'n/a (gpo-store only)',
  localfirewallrules         => 'n/a (gpo-store only)',
  logallowedconnections      => 'disable',
  logdroppedconnections      => 'disable',
  maxfilesize                => '4096',
  remotemanagement           => 'disable',
  state                      => 'on',
  unicastresponsetomulticast => 'enable',
}
windows_firewall_profile { 'private':
  filename                   => '%systemroot%\system32\logfiles\firewall\pfirewall.log',
  firewallpolicy             => 'blockinbound,allowoutbound',
  inboundusernotification    => 'disable',
  localconsecrules           => 'n/a (gpo-store only)',
  ...
```

Note that some settings are read-only

#### Turning profile firewalls on/off

Use the `state` property on some or all of the profiles:

```puppet
windows_firewall_profile { 'private':
  state => false, # off
}

windows_firewall_profile { ['public', 'domain']:
  state => true, # on
}
```

The values `true`/`on` or `false`/`off` are acceptable. If supplying data from 
YAML files in Hiera, `on` and `off` will be implicitly  
[converted to boolean](https://yaml.org/refcard.html)

#### Managing settings

Manage the settings for each of the three profiles you want to manage. To set 
everything to the same value, use an array for `title`:

```puppet
windows_firewall_profile { ['domain', 'private']:
  inboundusernotification    => 'enable',
  firewallpolicy             => 'allowinbound,allowoutbound',
  logallowedconnections      => 'enable',
  logdroppedconnections      => 'enable',
  maxfilesize                => '4000',
  remotemanagement           => 'enable',
  state                      => 'on',
  unicastresponsetomulticast => 'disable',
}
```

## Troubleshooting
* Try running puppet in debug mode (`--debug`)
* To reset firewall to default rules: `netsh advfirewall reset` **You need this
  if your getting `no rules match` errors or errors from global settings**
* You may get `missing parameter` errors from Puppet after upgrading the module.
  These can normally be fixed by [removing older versions and restarting Puppet
  Master](https://github.com/GeoffWilliams/puppet-windows_firewall/issues/7)
* Print all firewall rules using netsh 
  `netsh advfirewall firewall show rule all verbose`
* Print all firewall rules as read by Puppet 
  `powershell -file lib\ps\windows_firewall\ps-bridge.ps1 show`
* Print firewall global settings `netsh advfirewall show global`
* Print firewall profile settings `netsh advfirewall show allprofiles`
* Use the "Windows Firewall with advanced security" program if you would like a
  GUI to view/edit firewall status
* Help on how to 
  [create firewall rules](https://docs.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule?view=win10-ps)
* Help on how to 
  [change global settings](doc/netsh_global_settings.txt) (obtained from: 
  `netsh advfirewall set global`)
* Help on how to [change profile settings](doc/netsh_profile_settings.txt) 
  (obtained from: `netsh advfirewall set private`)

## Limitations
* `netsh` is used to enumerate most rules and is very fast. In some cases 
  `netsh` will be unable to resolve names for some rules so we fallback to
  PowerShell instead. This is handled by the `ps-bridge.ps1`
* Enumerate rules using PowerShell API is very slow. There's not much more that
  can be done about this short of deleting the offending rules.
* Deleting (purging) rules is very slow (~5-10 minutes) This is because deleting
  these rules with PowerShell is slow. There's not much that can be done about
  this but once unwanted rules are deleted (Windows 10 ships with ~300 rules)
  future operations will be a lot faster  
* Requires the `netsh advfirewall` command and PowerShell 
* Property names match those used by PowerShell (groups, rules) and `netsh` for
  everything else so there is inconsistency in the equivalent puppet property
  names and values (some names are run-together, others separated by
  underscores). This is deliberate and makes the module code much simpler as 
  names map exactly
* It is not possible to edit the `grouping` for rules (netsh does not support 
  this)
* It is not possible to edit the `localfirewallrules` or `localconsecrules` for
  profiles (this needs corresponding group policy)
* The Windows Advanced Firewall GUI allows multiple individual types to be set 
  for ICMPv4 and ICMPv6 however this does not seem to be possible through the 
  `netsh` CLI. Therefore you must create individual rules if for each type you 
  wish to allow if you want to limit a rule in this way, eg:
  
  ```puppet
  windows_firewall_rule { "allow icmp echo":
    ensure    => present,
    protocol  => "icmpv4",
    icmp_type => "8",
    action    => "allow",
  }

  windows_firewall_rule { "allow icmp time exceeded":
    ensure    => present,
    protocol  => "icmpv4",
    icmp_type => "11",
    action    => "allow",
  }
  ```   

## Development

PRs accepted :)

## Testing
Automatic testing using PDQTest 2. Needs to be run in a throw-away VM since its
impossible to manage the firewall in containerised Windows:

https://social.msdn.microsoft.com/Forums/en-US/3c5be919-765b-4ea6-936b-60f3ac0986aa/windows-firewall-service-is-stopped-on-windows-container

## Source
This is a fork of https://github.com/GeoffWilliams/puppet-windows_firewall