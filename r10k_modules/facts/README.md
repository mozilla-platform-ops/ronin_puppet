# facts

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)

## Description

This module provides a collection of facts tasks and plans all of which retrieve facts from the specified targets but each of them processes the retrieved facts differently. The provided plans are:
* `facts` - retrieves the facts and then stores them in the inventory, returns a result set wrapping result objects for each specified target which in turn wrap the retrieved facts
* `facts::info` - retrieves the facts and returns information about each target's OS compiled from the `os` fact value retrieved from that target

The provided tasks:
* `facts` - retrieves the facts and without further processing returns a result set wrapping result objects for each specified target which in turn wrap the retrieved facts (this task is used by the above plans). This task relies on cross-platform task support; if unavailable, the individual implementations can be used instead.
* `facts::bash` - bash implementation of fact gathering, used by the `facts` task.
* `facts::powershell` - powershell implementation of fact gathering, used by the `facts` task.
* `facts::ruby` - ruby implementation of fact gathering, used by the `facts` task.

`puppet_agent` module support:
The `puppet_agent::install_shell` task uses the `bash.sh` implementation code to gather facts. When `bash.sh` is invoked with the positional argument `platform` or `release` *only* the requested fact is returned. 

Example
```
root@y77tzpv6qxnx5at:~# ./bash.sh 
{
  "os": {
    "name": "Ubuntu",
    "release": {
      "full": "16.04",
      "major": "16",
      "minor": "04"
    },
    "family": "Debian"
  }
}
root@y77tzpv6qxnx5at:~# ./bash.sh "release"
16.04
root@y77tzpv6qxnx5at:~# ./bash.sh "platform"
Ubuntu
```

## Requirements

This module is compatible with the version of Puppet Bolt it ships with.

## Usage

To run the facts plan run

```
bolt plan run facts --targets target1.example.com,target2.example.com
```

### Parameters

All plans have only one parameter:

* `targets` - The targets to retrieve the facts from.

## Reference

The core functionality is implemented in the `facts` task, which provides implementations
for the `shell`, `powershell`, and `puppet-agent` features. The powerhsell and bash implementations of the task compile and return information
mimicking that provided by facter's `os` fact. When the `puppet-agent` feature is available the ruby implementation will return the result running `facter --json` on the target.
