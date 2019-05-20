# windowstime

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with windowstime](#setup)
    * [What windowstime affects](#what-windowstime-affects)
    * [Beginning with windowstime](#beginning-with-windowstime)
3. [Development - Guide for contributing to the module](#development)

## Description

This module configures NTP sync on Windows Servers. It's extremely useful on standalone instances not connected to AD. It switches the W32time Service from triggered to running, so it's constantly verifying and syncing the clock. It can also configure the systems in the correct timezone.
## Setup

### What windowstime affects

* Alters the HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters\NtpServer to the defined list (and flags) of NTP servers.
* Configures the w32time service.
* Does an initial resync.
* If timezone is set, it will configure the system to the specified timezone.

### Beginning with windowstime

You can just include the class to configure the server to sane defaults:

```puppet 
  include ::windowstime
```

Or configure your own NTP servers:
```puppet
    class { 'windowstime':
      servers => { 'pool.ntp.org'     => '0x01',
                   'time.windows.com' => '0x01',
                 }
    }
```

Or configure your NTP servers and the timezone:
```puppet
    class { 'windowstime':
      servers  => { 'pool.ntp.org'     => '0x01',
                    'time.windows.com' => '0x01',
                  },
      timezone => 'Greenwich Standard Time',
    }
```

Timezone values are validated to parameters accepted from the tzutil command. You can check the full list on data/common.yaml.



Please ensure that servers have the correct flag:

- 0x01 SpecialInterval
- 0x02 UseAsFallbackOnly
- 0x04 SymmatricActive
- 0x08 Client

## Development

Regular rules apply, send a PR and I promise to look at it as soon as I can.
