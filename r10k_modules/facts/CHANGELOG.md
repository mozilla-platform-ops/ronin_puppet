# Change Log

## 1.4.0
### Changed
- Bump maximum Puppet version to include 7.x

## 1.3.0
### Changed
- Look for and prefer `.bat` executables for windows platforms in the ruby implementation.
- Update task metadata to explicitly define file requirements and input_method.

## 1.2.0
### Changed
- Replace `facter -p` with `puppet facts show` for Puppet 7.

## 1.1.0
### Added
- The prototype `facts::external` plan can be used to gather external facts based on a provided modulepath.

### Changed
- The Powershell implementation now searches for `facter.exe` on Windows platforms.

### Fixed
- The `facts` task now correctly outputs errors.

## 1.0.0
### Changed
- The `$nodes` parameter was changed to `$targets` in both the `facts` and `facts::info` plans.

### Fixed
- Bash implementation now correctly detects platform information when using bash 3.1 and 3.2.
- Bash implementation now correctly returns the platform version when using `uname` to determine the platform name and version.

## 0.6.0
### Added
- The `bash.sh` implementation can now provide distro code-name when possible.

## 0.5.1
### Fixed
- Powershell implementation now correctly detects windows server 2019 and handles incompatible powershell version gracefully.
- Typo in bash implementation causing script to crash when interrogating /usr/bin/os-release has been corrected.

## 0.5.0
### Changed
- Extra implementations of the primary task will now be hidden in tools that support implementations and the 'private' property (like Bolt).
- Only use facter to compute facts when the puppet-agent feature is available on target in the ruby implementation.

### Fixed
- Works with Facter 2.

## 0.4.1
### Changed
- Only install bolt for testing when GEM_BOLT environment variable is set.

## 0.4.0
### Added
- The `bash.sh` implementation can accept the positional arguments `platform` or `release` to support the `puppet_agent::install` task. 

## 0.3.1
### Fixed
- Allow setting Puppet gem version via `PUPPET_GEM_VERSION` so we can use Puppet 5 to ship the module.

## 0.3.0
### Fixed
- Task metadata specifies environment input to work around BOLT-691.

### Changed
- Stop hiding failures gathering facts in the `facts` plan.

### Removed
- `facts::retrieve` as redundant with the `facts` task when cross-platform
tasks are supported.

## 0.2.0
### Added
- Legacy facts added to results.
- Improve ability of bash and ruby task to find facter executable path.

## 0.1.2

### Changed
- Move facts to external module (from bolt).
