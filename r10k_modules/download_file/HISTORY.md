## [v2.1.0](https://github.com/voxpupuli/puppet-download_file/tree/v2.1.0) (2017-02-11)

This is the last release with puppet3 support!
* Fix several markdown issues
* Add missing badges
* Rubocop: Fix RSpec/ImplicitExpect
* Set min version_requirement for Puppet + deps

## 2016-08-19 - Release 2.0.0

* Modulesync with latest Vox Pupuli defaults
* Add fields for proxy credentials
* Fix powershell file generation
* deprecate proxyAddress and change the new parameters to snake case
* Drop of ruby1.8.7 Support


##2016-01-18 - Release 1.3.0
###Summary

This release fixes the default timeout value for exec and also deprecates
the proxyAddress variable in favor of proxy_address


##2015-04-17 - Release 1.2.1
###Summary

This release contains various changes needed after the move to the
puppet-community namespace


##2014-10-17 - Release 1.1.1
###Summary

This releases fixes a bug where duplicate resources can occur


####Bugfixes

- fixes (#10) where C:\Temp and C:/Temp throws duplicate resource error


##2014-10-17 - Release 1.1.0
###Summary

This release adds support to provide the file location


####Features

- Adds new parameter `destination_file` to provide the name of the file to download onto the system.


##2014-10-10 - Release 1.0.0
###Summary

This release has some bug fixes but is mostly improving the documentation and testing
to bring it up to a higher quality standard.

####Bug Fixes

- adding condition to check if C:\temp has already been defined


##2014-02-24 - Release 0.0.2
###Summary

Minor update to include improved documentation of the proxy parameters


##2013-11-29 - Release 0.0.1
###Summary

Initial public release of the module
