# scheduled_task

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with scheduled_task](#setup)
    * [Beginning with scheduled_task](#beginning-with-scheduled_task)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

<a id="description"></a>
## Description

This module adds a new [scheduled_task](https://puppet.com/docs/puppet/latest/types/scheduled_task.html) provider capable of using the more modern Version 2 Windows API for task management.
The legacy API does not receive improvements or new features, meaning that if you want to take advantage of improvements to scheduled tasks on Windows you need to use the V2 API.

<a id="setup"></a>
## Setup

<a id="beginning-with-scheduled_task"></a>
### Beginning with scheduled_task

The scheduled_task module adapts the Puppet [scheduled_task](https://puppet.com/docs/puppet/latest/types/scheduled_task.html) resource to run using a modern API.
To get started, install the module and any existing `scheduled_task` resources will use the V2 API **by default**.
If you want to continue using the provider for the legacy API you will _need_ to declare that in your manifests.
For example:

~~~ puppet
scheduled_task { 'Run Notepad':
  command  => "notepad.exe",
  ...
  provider => 'win32_taskscheduler',
}
~~~

<a id="usage"></a>
## Usage

Scheduled tasks are commonly used to kick off a script either once or on a regular cadence.
In this first example we schedule a cleanup script to run this one time.

~~~ puppet
scheduled_task { 'Disk Cleanup': # Unique name for the scheduled task
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',           # This is the default, but including it is good practice. Flip to 'false' to disable the task.
  trigger   => [{
    schedule   => 'once',        # Defines the trigger type; required.
    start_time => '23:20',       # Defines the time the task should run; required.
    start_date => '2018-01-01'   # Defaults to the current date; not required.
  }],
}
~~~

If we need to have the cleanup script run every night we can use a daily trigger.
Just changing the trigger schedule from `once` to `daily` will do the trick.
Note that we removed the `start_date` from the trigger - it isn't required and, for this task, isn't important.

~~~ puppet
scheduled_task { 'Disk Cleanup Nightly':
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    schedule   => 'daily',
    start_time => '23:20'
  }],
}
~~~

You can also set your scheduled tasks to repeat during a set time block.
Using the cleanup script again, this scheduled task begins at the same time every day and runs once an hour from seven in the morning to seven at night as the SYSTEM account.

~~~ puppet
scheduled_task { 'Disk Cleanup Daily Repeating':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'         => 'daily',
    'start_time'       => '07:00',
    'minutes_duration' => '720',   # Specifies the length of time, in minutes, the task is active
    'minutes_interval' => '60'     # Causes the task to run every hour
  }],
  user      => 'system',           # Specifies the account to run the task as
}
~~~

The downside to that task is that it causes the cleanup script to run _every_ day, even on the weekends when there is no activity.
We can instead use a weekly trigger to fix this:

~~~puppet
scheduled_task { 'Disk Cleanup Weekly Repeating':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'         => 'weekly',
    'start_time'       => '07:00',
    'day_of_week'      => ['mon', 'tues', 'wed', 'thurs', 'fri'], # Note the absence of Saturday and Sunday
    'minutes_interval' => '60',
    'minutes_duration' => '720'
  }],
  user      => 'system',
}
~~~

Similarly, we can schedule our cleanup script to run monthly if we decide the cleanup script doesn't need to run as often or is particularly resource intensive.
The following example sets the scheduled task to run at 0700 on the first day of the month every month:

~~~puppet
scheduled_task { 'Disk Cleanup Monthly First Day':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'   => 'monthly',
    'start_time' => '07:00',
    'on'         => [1]        # Run every month on the first day of the month.
  }],
  user      => 'system',
}
~~~

With the monthly trigger above there is no guarantee that the first day of the month is on a weekend.
This means that there's a reasonable chance that the script will execute during working hours and impact productivity.
We can specify the trigger to run on the task on the _first saturday_ of the month instead of the first day:

~~~puppet
scheduled_task { 'Disk Cleanup Monthly First Saturday':
  ensure    => 'present',
  command   => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled   => 'true',
  trigger   => [{
    'schedule'        => 'monthly',
    'start_time'      => '07:00',
    'day_of_week'     => 'sat',     # Specify the day of the week to trigger on
    'which_occurence' => 'first'    # Specify which occurance to trigger on, up to fifth
  }],
  user      => 'system',
}
~~~

You might also want a task to run every time the computer boots.

~~~puppet
scheduled_task { 'Disk Cleanup On Restart':
  ensure        => 'present',
  compatibility => 2,
  command       => "$::system32\\WindowsPowerShell\\v1.0\\powershell.exe",
  arguments     => '-File "C:\\Scripts\\Clear-DiskSpace.ps1"',
  enabled       => 'true',
  trigger       => [{
    'schedule'  => 'boot',
    'minutes_interval' => '60',
    'minutes_duration' => '720'
  }],
  user          => 'system',
}
~~~
* Note: Duration properties like `minutes_duration` and `minutes_interval` must have `compatibility => 2` or higher specified for `boot` triggers. Windows does not support those options at the "Windows XP or Windows Server 2003 computer" compatibility level which is the default when compatibility is left unspecified.

If you want a task to run at logon, use the `logon` trigger:

~~~puppet
scheduled_task { 'example_notepad':
  compatibility => 2,
  command       => 'C:\\Windows\\System32\\notepad.exe',
  trigger       => [{
    schedule => 'logon',
    user_id  => 'MyDomain\\SomeUser'
  }],
}
~~~

<a id="reference"></a>
## Reference

### Provider

* win32_taskscheduler: This legacy provider manages scheduled tasks on Windows imitating the legacy API.
* taskscheduler_api2: Adapts the Puppet scheduled_task resource to use the modern Version 2 API.

### Type

#### scheduled_task

Installs and manages Windows Scheduled Tasks.
All attributes except `name`, `command`, and `trigger` are optional; see the description of the [`trigger`](#trigger) attribute for details on setting schedules.

##### `name`

The name assigned to the scheduled task.
This will uniquely identify the task on the system.
If specifying a scheduled task inside of subfolder(s), specify the path from root, such as `subfolder\\mytaskname`.
This will create the scheduled task `mytaskname` in the container named `subfolder`.
You can only specify a taskname inside of subfolders if the compatibility is set to 2 or higher and when using the taskscheduler2_api provider.

##### `ensure`

The basic property that the resource should be in.

Valid values are `present`, `absent`.

##### `arguments`

Any arguments or flags that should be passed to the command.
Multiple arguments should be specified as a space-separated string.

##### `command`

The full path to the application to run, without any arguments.

##### `enabled`

Whether the triggers for this task should be enabled.
This attribute affects every trigger for the task; triggers cannot be enabled or disabled individually.

Valid values are `true`, `false`.

##### `password`

The password for the user specified in the 'user' attribute.
This is only used if specifying a user other than 'SYSTEM'.
This parameter will not be used to determine if a scheduled task is in sync or not because there is no way to retrieve the password used to set the account information for a task.

##### `compatibility`

This provider feature is only available with the `taskscheduler_api2` provider.

The compatibility level associated with the task.
Defaults to 1 for backward compatibility.
Can be set to:

- `1` for compatibility with tasks on a Windows XP or Windows Server 2003 computer
- `2` for compatibility with tasks on a Windows 2008 computer
- `3` for compatibility with new features for tasks introduced in Windows 7 and 2008R2
- `4` for compatibility with new features for tasks introduced in Windows 8, Server 2012R2 and Server 2016
- `6` for compatibility with new features for tasks introduced in Windows 10
  - **NOTE:** This compatibility setting is _not_ documented and we recommend that you do not use it.

See the [Microsoft documentation on compatibility levels and their differences](https://msdn.microsoft.com/en-us/library/windows/desktop/aa384138\(v=vs.85\).aspx) for more information.

##### `provider`

The specific backend to use for this scheduled_task resource.
You will seldom need to specify this — Puppet will usually discover the appropriate provider for your platform.

Available providers are:

###### win32_taskscheduler

This legacy provider manages scheduled tasks on Windows using the v2 api but only manages scheduled tasks whose compatibility level is set to 1 (Windows XP or Windows Server 2003).
It is a backward compatible update and replaces the provider of the same name in Puppet core.

###### taskscheduler_api2

This provider manages scheduled tasks on Windows using the v2 api and can manage scheduled tasks of any compatibility level.

* Default for `operatingsystem` == `windows`.

##### `trigger`

One or more triggers defining when the task should run.
A single trigger is represented as a hash, and multiple triggers can be specified with an array of hashes.

A trigger can contain the following keys:

For all triggers:

* `schedule` (Required) — What kind of trigger this is.
  Valid values are `daily`, `weekly`, `monthly`, `once`, `boot`, or `logon`.
  Each kind of trigger is configured with a different set of keys; see the sections below (once triggers only need a start time/date.)
* `start_time` (Required except for `boot`) — The time of day when the trigger should first become active.
  Several time formats will work, but we suggest 24-hour time formatted as HH:MM.
* `start_date` — The date when the trigger should first become active.
  Defaults to the current date.
  You should format dates as YYYY-MM-DD, although other date formats may work (under the hood, this uses Date.parse).
* `minutes_interval` — The repeat interval in minutes.
* `minutes_duration` — The duration in minutes, needs to be greater than the minutes_interval.
* For daily triggers:
  * `every` — How often the task should run, as a number of days.
    Defaults to 1.
    "2" means every other day, "3" means every three days, etc.
* For weekly triggers:
  * `every` — How often the task should run, as a number of weeks.
    Defaults to 1.
    "2" means every other week, "3" means every three weeks, etc.
  * `day_of_week` — Which days of the week the task should run, as an array.
    Defaults to all days.
    Each day must be one of `mon`, `tues`, `wed`, `thurs`, `fri`, `sat`, `sun`, or `all`.
* For monthly (by date) triggers:
  * `months` — Which months the task should run, as an array.
    Defaults to all months.
    Each month must be an integer between 1 and 12.
  * `on` (Required) — Which days of the month the task should run, as an array.
    Each day must be an integer between 1 and 31.
    * The string `last` may be used in the array for this property to trigger a
    task to run on the last day of each selected month. This feature is only
    available for tasks with compatibility level `2` or higher.
* For monthly (by weekday) triggers:
  * `months` — Which months the task should run, as an array. Defaults to all months. Each month must be an integer between 1 and 12.
  * `day_of_week` (Required) — Which day of the week the task should run, as an array with only one element.
    Each day must be one of `mon`, `tues`, `wed`, `thurs`, `fri`, `sat`, `sun`, or `all`.
  * `which_occurrence` (Required) — The occurrence of the chosen weekday when the task should run. Must be one of `first`, `second`, `third`, `fourth`, or `last`.
* For `logon` triggers:
  * `user_id` --- The `user_id` specifies _which_ user this task will trigger
    for when they logon. If unspecified, or if specified as `undef` or an empty
    string, the task will trigger whenever **any** user logs on. This property
    can be specified in one of the following formats:
    * Local User: `"Administrator"`
    * Domain User: `"MyDomain\\MyUser"`
    * SID: `"S-15-..."`
    * Any User: `''` or `undef`

##### `user`

The user to run the scheduled task as.
Defaults to 'SYSTEM'.

Please also note that Puppet must be running as a privileged user in order to manage `scheduled_task` resources.
Running as an unprivileged user will result in 'access denied' errors.

##### `working_dir`

The full path of the directory in which to start the command.

<a id="limitations"></a>
## Limitations

* Only supported on Windows Server 2008 and above, and Windows 7 and above.

<a id="development"></a>
## Development

Puppet modules on the Puppet Forge are open projects, and community contributions are essential for keeping them great. We can't access the huge number of platforms and myriad hardware, software, and deployment configurations that Puppet is intended to serve, therefore want to keep it as easy as possible to contribute changes so that our modules work in your environment. There are a few guidelines that we need contributors to follow so that we can have a chance of keeping on top of things. 
If you would like to contribute to this module, please follow the rules in the [CONTRIBUTING.md](https://github.com/puppetlabs/puppetlabs-scheduled_task/blob/main/CONTRIBUTING.md). For more information, see our [module contribution guide.](https://puppet.com/docs/puppet/latest/contributing.html).
