
# timezone

Configures the system timezone.

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with timezone](#setup)
    * [What timezone affects](#what-timezone-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with timezone](#beginning-with-timezone)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

## Description

This module configures the system timezone.

## Setup

### What timezone affects

* Installs timezone package.
* Configures the system timezone.
* Configures whether the RTC is on UTC or local time.

### Setup Requirements

* Supported OS with timezone package available in a configured package repository.
* puppetlabs/stdlib module.

### Beginning with timezone

To configure the system timezone to UTC with the RTC set on UTC:

    class { 'timezone':
      timezone   => 'UTC',
      rtc_is_utc => true,
    }

## Usage

#### Configures the system for timezone UTC with RTC on UTC time.

    class { 'timezone':
      timezone   => 'UTC',
      rtc_is_utc => true,
    }

#### Previous example but configured with data provided by hiera.

    timezone::timezone:   'UTC'
    timezone::rtc_is_utc: true

    include timezone

#### Configures the system for timezone Europe/Stockholm with RTC on UTC time.

    class { 'timezone':
      timezone   => 'Europe/Stockholm',
      rtc_is_utc => true,
    }

#### Previous example but configured with data provided by hiera.

    timezone::timezone:   'Europe/Stockholm'
    timezone::rtc_is_utc: true

    include timezone

## Limitations

Tested on CentOS 7, Debian 9, Fedora 29, SLES 15 and Ubuntu 18.04.

## Development

All bugreports, suggestions and patches will be considered.
