## 1.0.1

### Fixed

- Ensure compatibility with Ruby 1.9 to support catalog compilation in PE 2016.4.x ([MODULES-8695](https://tickets.puppetlabs.com/browse/MODULES-8695)) - thanks, [@reidmv](https://github.com/reidmv)!

## [1.0.0] - 2018-09-11

### Changed

- Module status to `Supported` - no breaking changes will be introduced until `2.0.0`.

## [0.4.0] - 2018-08-23

### Added

- `logon` trigger support ([MODULES-6267](https://tickets.puppetlabs.com/browse/MODULES-7129))
- Enabled localization ([PUP-9053](https://tickets.puppetlabs.com/browse/PUP-9053))

### Fixed

- Ensure setting a user for a task is possible ([MODULES-7240](https://tickets.puppetlabs.com/browse/MODULES-7240))

## [0.3.0] - 2018-05-25

### Added

- `boot` trigger support ([MODULES-6267](https://tickets.puppetlabs.com/browse/MODULES-6267))

## [0.2.0] - 2018-05-09

### Added

- `compatibility` feature and flag (usable only with the `taskscheduler_api2` provider), allowing users to specify which version of Scheduled Tasks the task should be compatible with; defaults to 1 for backward compatibility ([MODULES-6526](https://tickets.puppetlabs.com/browse/MODULES-6526))
- Documentation of the legacy `win32_taskscheduler` provider and the `taskscheduler_api2`, ensuring users will not need to refer to Puppet core documentation ([MODULES-6417](https://tickets.puppetlabs.com/browse/MODULES-6417))
- New helper for `taskscheduler_api2` allowing it to manage scheduled tasks of any compatibility level ([MODULES-6844](https://tickets.puppetlabs.com/browse/MODULES-6844), [MODULES-6845](https://tickets.puppetlabs.com/browse/MODULES-6845))

### Changed

- Default provider from `win32_taskscheduler` to `taskscheduler_api2` ([MODULES-6591](https://tickets.puppetlabs.com/browse/MODULES-6591))
- Logic for managing triggers, refactoring for improved maintainability ([MODULES-6843](https://tickets.puppetlabs.com/browse/MODULES-6843), [MODULES-6895](https://tickets.puppetlabs.com/browse/MODULES-6895))
- `win32_taskscheduler` to use the adapter code developed for `taskscheduler_api2` for improved maintainability ([MODULES-6845](https://tickets.puppetlabs.com/browse/MODULES-6845))

### Fixed

- Metadata to ensure a correct link on the Puppet Forge, by [@TraGicCode](https://github.com/TraGicCode) in [PR 12](https://github.com/puppetlabs/puppetlabs-scheduled_task/pull/12)
- Metadata to support only Puppet version `4.9.0` and above, as earlier versions do not support translation, which this module uses (MAINT)
- Error message for a user-specified invalid value for the `day_of_week`, ensuring that the resulting error communicates the actual problem to the user ([MODULES-6398](https://tickets.puppetlabs.com/browse/MODULES-6398))
- Conflation of two types of monthly triggers, separating them into distinct triggers to prevent erroneous error messages ([MODULES-6268](https://tickets.puppetlabs.com/browse/MODULES-6268))
- Setting of triggers in timezones other than UTC, ensuring that the specified times in triggers will be applied as local-time on the node ([MODULES-7026](https://tickets.puppetlabs.com/browse/MODULES-7026))

### Removed

- Code for and references to `random_minutes_interval`, a property which has never been usable/setable and has been hard-coded to 0 in previous releases ([MODULES-7071](https://tickets.puppetlabs.com/browse/MODULES-7071))

## [0.1.0] - 2018-01-12

### Added

- Added V2 provider for the V1 Puppet type ([MODULES-6264](https://tickets.puppetlabs.com/browse/MODULES-6264), [MODULES-6266](https://tickets.puppetlabs.com/browse/MODULES-6266))

### Changed

- Updated README with examples for the new provider ([MODULES-6264](https://tickets.puppetlabs.com/browse/MODULES-6264))
- Updated acceptance tests for the new provider ([MODULES-6362](https://tickets.puppetlabs.com/browse/MODULES-6362))

[1.0.1]: https://github.com/puppetlabs/puppetlabs-scheduled_task/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/puppetlabs/puppetlabs-scheduled_task/compare/0.4.0...1.0.0
[0.4.0]: https://github.com/puppetlabs/puppetlabs-scheduled_task/compare/0.3.0...0.4.0
[0.3.0]: https://github.com/puppetlabs/puppetlabs-scheduled_task/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/puppetlabs/puppetlabs-scheduled_task/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/puppetlabs/puppetlabs-scheduled_task/compare/10cb19e08bc6b198e25a633aec5ce4157ae4d283...0.1.0
