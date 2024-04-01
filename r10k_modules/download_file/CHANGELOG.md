# Changelog

All notable changes to this project will be documented in this file.
Each new release typically also includes the latest modulesync defaults.
These should not affect the functionality of the module.

## [v4.0.0](https://github.com/voxpupuli/puppet-download_file/tree/v4.0.0) (2020-04-07)

[Full Changelog](https://github.com/voxpupuli/puppet-download_file/compare/v3.2.0...v4.0.0)

**Breaking changes:**

- modulesync 2.7.0 and drop puppet 4 [\#88](https://github.com/voxpupuli/puppet-download_file/pull/88) ([bastelfreak](https://github.com/bastelfreak))

**Implemented enhancements:**

- Allow enabled SSL protocols to be specified [\#86](https://github.com/voxpupuli/puppet-download_file/pull/86) ([aadamovich](https://github.com/aadamovich))

**Closed issues:**

- puppetlabs/stdlib version below 6.0.0 [\#96](https://github.com/voxpupuli/puppet-download_file/issues/96)
- Delete powershell file after download complete [\#31](https://github.com/voxpupuli/puppet-download_file/issues/31)

**Merged pull requests:**

- Allow puppetlabs/stdlib 6.x [\#97](https://github.com/voxpupuli/puppet-download_file/pull/97) ([dhoppe](https://github.com/dhoppe))
- Remove duplicate CONTRIBUTING.md file [\#93](https://github.com/voxpupuli/puppet-download_file/pull/93) ([dhoppe](https://github.com/dhoppe))
- Remove spurious space from operatingsystem [\#89](https://github.com/voxpupuli/puppet-download_file/pull/89) ([ekohl](https://github.com/ekohl))

## [v3.2.0](https://github.com/voxpupuli/puppet-download_file/tree/v3.2.0) (2018-10-14)

[Full Changelog](https://github.com/voxpupuli/puppet-download_file/compare/v3.1.0...v3.2.0)

**Implemented enhancements:**

- No authentication [\#9](https://github.com/voxpupuli/puppet-download_file/issues/9)
- Adding basic auth capability to downloadfile [\#75](https://github.com/voxpupuli/puppet-download_file/pull/75) ([scottpecnik](https://github.com/scottpecnik))

**Merged pull requests:**

- modulesync 2.1.0 and allow puppet 6.x [\#83](https://github.com/voxpupuli/puppet-download_file/pull/83) ([bastelfreak](https://github.com/bastelfreak))
- allow puppetlabs/stdlib 5.x [\#80](https://github.com/voxpupuli/puppet-download_file/pull/80) ([bastelfreak](https://github.com/bastelfreak))
- Remove docker nodesets [\#76](https://github.com/voxpupuli/puppet-download_file/pull/76) ([bastelfreak](https://github.com/bastelfreak))

## [v3.1.0](https://github.com/voxpupuli/puppet-download_file/tree/v3.1.0) (2018-03-30)

[Full Changelog](https://github.com/voxpupuli/puppet-download_file/compare/v3.0.0...v3.1.0)

**Implemented enhancements:**

- Optional parameter user\_agent [\#65](https://github.com/voxpupuli/puppet-download_file/pull/65) ([ofalk](https://github.com/ofalk))
- Fix error duplicate resource when url has same ending [\#63](https://github.com/voxpupuli/puppet-download_file/pull/63) ([devcfgc](https://github.com/devcfgc))

**Merged pull requests:**

- bump puppet to latest supported version 4.10.0 [\#70](https://github.com/voxpupuli/puppet-download_file/pull/70) ([bastelfreak](https://github.com/bastelfreak))

## [v3.0.0](https://github.com/voxpupuli/puppet-download_file/tree/v3.0.0) (2017-10-19)

[Full Changelog](https://github.com/voxpupuli/puppet-download_file/compare/v2.1.0...v3.0.0)

**Breaking changes:**

- Replace validate\_\* calls with datatypes [\#58](https://github.com/voxpupuli/puppet-download_file/pull/58) ([bastelfreak](https://github.com/bastelfreak))

**Merged pull requests:**

- Release 3.0.0 [\#61](https://github.com/voxpupuli/puppet-download_file/pull/61) ([bastelfreak](https://github.com/bastelfreak))
- Add cookie support [\#54](https://github.com/voxpupuli/puppet-download_file/pull/54) ([spacepants](https://github.com/spacepants))
- modulesync 0.19.3 [\#51](https://github.com/voxpupuli/puppet-download_file/pull/51) ([bastelfreak](https://github.com/bastelfreak))

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


\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
