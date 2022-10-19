# Scoop

#### Table of Contents


1. [Module Description - What the module does and why it is useful](#module-description)
1. [Setup - The basics of getting started with scoop](#setup)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

<a id="module-description"></a>
## Module description

The scoop module installs Scoop, Scoop buckets and packages

<a id="setup"></a>
## Setup

### Beginning with scoop

`include scoop` is enough to get you up and running. To pass in parameters specifying which buckets or packages to install:

```puppet
class { 'scoop':
  packages => [ 'firefox', 'ripgrep' ],
  buckets  => [ 'extras' ],
  url_buckets => {
    'wangzq' => 'https://github.com/wangzq/scoop-bucket'
  },
}
```

<a id="usage"></a>
## Usage

You can configure scoop quicly using the parameters for the main class, or use the resources contained in the module for finer controls.

### Install and enable Scoop

```puppet
include scoop
```

### Install packages

```puppet
class { 'scoop':
  packages => [ 'firefox', 'ripgrep' ],
}
```

### Configure extra (known) buckets and install packages

```puppet
class { 'scoop':
  packages => [ 'firefox', 'ripgrep' ],
  buckets  => [ 'extras' ],
}
```

### Configure a bucket via URL

```puppet
class { 'scoop':
  url_buckets => {
    'wangzq' => 'https://github.com/wangzq/scoop-bucket'
  },
}
```

### Remove scoop from the system

```puppet
class { 'scoop':
  ensure => absent,
}
```

<a id="reference"></a>
## Reference

See [REFERENCE.md](./REFERENCE.md)