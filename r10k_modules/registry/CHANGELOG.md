# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v4.1.0](https://github.com/puppetlabs/puppetlabs-registry/tree/v4.1.0) (2022-06-06)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/v4.0.1...v4.1.0)

### Added

- pdksync - \(FM-8922\) - Add Support for Windows 2022 [\#259](https://github.com/puppetlabs/puppetlabs-registry/pull/259) ([david22swan](https://github.com/david22swan))

## [v4.0.1](https://github.com/puppetlabs/puppetlabs-registry/tree/v4.0.1) (2021-08-23)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/v4.0.0...v4.0.1)

### Fixed

- Add possibility to produce a detailed error message  [\#254](https://github.com/puppetlabs/puppetlabs-registry/pull/254) ([reidmv](https://github.com/reidmv))

## [v4.0.0](https://github.com/puppetlabs/puppetlabs-registry/tree/v4.0.0) (2021-02-27)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/v3.2.0...v4.0.0)

### Changed

- pdksync - Remove Puppet 5 from testing and bump minimal version to 6.0.0 [\#236](https://github.com/puppetlabs/puppetlabs-registry/pull/236) ([carabasdaniel](https://github.com/carabasdaniel))

## [v3.2.0](https://github.com/puppetlabs/puppetlabs-registry/tree/v3.2.0) (2020-12-08)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/v3.1.1...v3.2.0)

### Added

- pdksync - \(feat\) Add support for Puppet 7 [\#231](https://github.com/puppetlabs/puppetlabs-registry/pull/231) ([daianamezdrea](https://github.com/daianamezdrea))
- pdksync - \(IAC-973\) - Update travis/appveyor to run on new default branch `main` [\#217](https://github.com/puppetlabs/puppetlabs-registry/pull/217) ([david22swan](https://github.com/david22swan))

## [v3.1.1](https://github.com/puppetlabs/puppetlabs-registry/tree/v3.1.1) (2020-08-12)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/v3.1.0...v3.1.1)

### Fixed

- \(IAC-967\) Puppet 7 compatibility fix: null termination for strings [\#216](https://github.com/puppetlabs/puppetlabs-registry/pull/216) ([sanfrancrisko](https://github.com/sanfrancrisko))

## [v3.1.0](https://github.com/puppetlabs/puppetlabs-registry/tree/v3.1.0) (2019-12-10)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/v3.0.0...v3.1.0)

### Added

- \(FM-8190\) convert module to litmus [\#190](https://github.com/puppetlabs/puppetlabs-registry/pull/190) ([DavidS](https://github.com/DavidS))

## [v3.0.0](https://github.com/puppetlabs/puppetlabs-registry/tree/v3.0.0) (2019-10-17)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-registry/compare/2.1.0...v3.0.0)

### Added

- \(FM-7693\) Add Windows Server 2019 [\#174](https://github.com/puppetlabs/puppetlabs-registry/pull/174) ([glennsarti](https://github.com/glennsarti))

### Fixed

- \(MODULES-5625\) Fail on empty strings in REG\_MULTI\_SZ [\#173](https://github.com/puppetlabs/puppetlabs-registry/pull/173) ([glennsarti](https://github.com/glennsarti))

## 2.1.0
### Added
- Updated module for Puppet 6 ([MODULES-7832](https://tickets.puppetlabs.com/browse/MODULES-7832))

### Changed
- Update module for PDK ([MODULES-7404](https://tickets.puppetlabs.com/browse/MODULES-7404))

## [2.0.2] - 2018-08-08
### Added
- Add Windows Server 2016 and Windows 10 as supported Operating Systems ([MODULES-4271](https://tickets.puppetlabs.com/browse/MODULES-4271))

### Changed
- Convert tests to use testmode switcher ([MODULES-6744](https://tickets.puppetlabs.com/browse/MODULES-6744))

### Fixed
- Fix types to no longer use unsupported proc title patterns ([MODULES-6818](https://tickets.puppetlabs.com/browse/MODULES-6818))
- Fix acceptance tests in server-agent scenarios ([FM-6934](https://tickets.puppetlabs.com/browse/FM-6934))
- Use case insensitive search when purging ([MODULES-7534](https://tickets.puppetlabs.com/browse/MODULES-7534))

### Removed

## [2.0.1] - 2018-01-25
### Fixed
- Fix the restrictive typing introduced for the registry::value defined type to once again allow numeric values to be specified for DWORD, QWORD and arrays for REG_MULTI_SZ values ([MODULES-6528](https://tickets.puppetlabs.com/browse/MODULES-6528))

## [2.0.0] - 2018-01-24
### Added
- Add support for Puppet 5 ([MODULES-5144](https://tickets.puppetlabs.com/browse/MODULES-5144))

### Changed
- Convert beaker tests to beaker rspec tests ([MODULES-5976](https://tickets.puppetlabs.com/browse/MODULES-5976))

#### Fixed
- Ensure registry values that include a `\` as part of the name are valid and usable ([MODULES-2957](https://tickets.puppetlabs.com/browse/MODULES-2957))

### Removed
- **BREAKING:** Dropped support for Puppet 3

## [1.1.4] - 2017-03-06
### Added
- Ability to manage keys and values in `HKEY_USERS` (`hku`) ([MODULES-3865](https://tickets.puppetlabs.com/browse/MODULES-3865))

### Removed
- Remove Windows Server 2003 from supported Operating System list

#### Fixed
- Use double quotes so $key is interpolated ([FM-5236](https://tickets.puppetlabs.com/browse/FM-5236))
- Fix WOW64 Constant Definition ([MODULES-3195](https://tickets.puppetlabs.com/browse/MODULES-3195))
- Fix UNSET no longer available as a bareword ([MODULES-4331](https://tickets.puppetlabs.com/browse/MODULES-4331))

## [1.1.3] - 2015-12-08
### Added
- Support of newer PE versions.

## [1.1.2] - 2015-08-13
### Added
- Added tests to catch scenario

### Changed
- Changed byte conversion to use pack instead

### Fixed
- Fix critical bug when writing dword and qword values.
- Fix the way we write dword and qword values [MODULES-2409](https://tickets.puppet.com/browse/MODULES-2409)

## [1.1.1] - 2015-08-12 [YANKED]
### Added
- Puppet Enterprise 2015.2.0 to metadata

### Changed
- Gemfile updates
- Updated the logic used to convert to byte arrays

### Fixed
- Fixed Ruby registry writes corrupt string ([MODULES-1921](https://tickets.puppet.com/browse/MODULES-1921))
- Fixed testcases

## [1.1.0] - 2015-03-24
### Fixes
- Additional tests for purge_values
- Use wide character registry APIs
- Test Ruby Registry methods uncalled
- Introduce Ruby 2.1.5 failing tests


## [1.0.3] - 2014-08-25
### Added
- Added support for native x64 ruby and puppet 3.7

### Fixed
- Fixed issues with non-leading-zero binary values in registry keys.

## [1.0.2] - 2014-07-15
### Added
- Added the ability to uninstall and upgrade the module via the `puppet module` command

## [1.0.1] - 2014-05-20
### Fixed
- Add zero padding to binary single character inputs

## [1.0.0] - 2014-03-04
### Added
- Add license file

### Changed
- Documentation updates

## [0.1.2] - 2013-08-01
### Added
- Add geppetto project file

### Changed
- Updated README and manifest documentation
- Refactored code into PuppetX namespace
- Only manage redirected keys on 64 bit systems
- Only use /sysnative filesystem when available
- Use class accessor method instead of class instance variable

### Fixed
- Fixed unhandled exception when loading windows code on *nix

## [0.1.1] - 2012-05-21
### Fixed
- Improve error handling when writing values
- Fix management of the default value

## [0.1.0] - 2012-05-16
### Added
- Initial release


\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
