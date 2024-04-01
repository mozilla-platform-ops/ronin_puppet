# Download File module for Puppet

[![Build Status](https://travis-ci.org/voxpupuli/puppet-download_file.png?branch=master)](https://travis-ci.org/voxpupuli/puppet-download_file)
[![Code Coverage](https://coveralls.io/repos/github/voxpupuli/puppet-download_file/badge.svg?branch=master)](https://coveralls.io/github/voxpupuli/puppet-download_file)
[![Puppet Forge](https://img.shields.io/puppetforge/v/puppet/download_file.svg)](https://forge.puppetlabs.com/puppet/download_file)
[![Puppet Forge - downloads](https://img.shields.io/puppetforge/dt/puppet/download_file.svg)](https://forge.puppetlabs.com/puppet/download_file)
[![Puppet Forge - endorsement](https://img.shields.io/puppetforge/e/puppet/download_file.svg)](https://forge.puppetlabs.com/puppet/download_file)
[![Puppet Forge - scores](https://img.shields.io/puppetforge/f/puppet/download_file.svg)](https://forge.puppetlabs.com/puppet/download_file)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with download_file](#setup)
    * [What download_file affects](#what-download_file-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with download_file](#beginning)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#contributing)

## Overview

The download_file module allows you to download files on Windows

## Module Description

The download_file module introduced a small define `download_file` that will
allow you to download a file over http(s) for usage during an installation.
This was created because the package resource does not support http as a source
for packages. It is only supported on Windows.

## Setup

### What download_file affects

* Downloads files onto each node

### Setup Requirements

* download_file makes use of Powershell so you will need to have at least
  version 2.0 installed in order to use this module.

### Beginning with download_file

To download dotnet 4.0

```puppet
    download_file { "Download dotnet 4.0" :
      url                   => 'http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe',
      destination_directory => 'c:\temp'
    }
```

To download dotnet 4.0 using a proxy

```puppet
    download_file { "Download dotnet 4.0" :
      url                   => 'http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe',
      destination_directory => 'c:\temp',
      proxy_address         => 'http://corporateproxy.net:8080'
    }
```

The proxy will be used as part of the download using PowerShell. This does not
set a system wide proxy

## Usage

## Reference

### Defined Types

#### Public Types

* `download_file`: Download a give file

### Parameters

#### `url`

The http(s) destination of the file that you are looking to download

#### `destination_directory`

The full path to the directory on the system where the file will be downloaded to

#### `destination_file`

The optional name of the file to download onto the system.

#### `user`

The optional userid is used when authenticating via Basic Auth with the server.
`user` and `password` must be specified or this has no effect.

#### `password`

The optional password is used when authenticating via Basic Auth with the server.
`user` and `password` must be specified or this has no effect.

#### `proxy_address`

The optional http proxy address to use when downloading the file

#### `proxy_user`

The optional http proxy user to use when downloading the file. `proxy_address`
and `proxy_password` must be specified or this has no effect.

#### `proxy_password`

The optional http proxy password to use when downloading the file. `proxy_address`
and `proxy_user` must be specified or this has no effect. By default this value
accepts secure strings. A secure string is (unfortunately) tied to the machine
that it is used for. To generate a secure string for a given machine, users
should run the following powershell command on that machine (replacing
PASSWORD with the desired password):

```Powershell
ConvertFrom-SecureString -securestring $(ConvertTo-SecureString "PASSWORD" -AsPlainText -Force)
```

It is possible to get this information then clear the command from history, but
it's important to note that the -Force argument is there to suppress warnings
that the plaintext password is in the history.

If this process sounds unappealing, you can send the password in plaintext
(which sits in the `download-<filename>.ps1` file on the machine being provisioned)
by changing the `is_password_secure` variable to `false`.

#### `is_password_secure`

The optional switch to change the way that `proxyPassword` is interpreted from
secure string to plaintext. This will send the password in plaintext to the
machine being provisioned, which may be a security concern.

#### `cookies`

An optional array of cookies to add to the HTTP request for the download.

## Limitations

This module is tested on the following platforms:

* Windows 2008
* Windows 2008 R2
* Windows 2012
* Windows 2012 R2
* Windows 7
* Windows 8

It is tested with the OSS version of Puppet only.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for full details on contributing
to this project.
