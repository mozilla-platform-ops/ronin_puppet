# Ronin Puppet: the masterless puppet collection

[![CircleCI Status](https://circleci.com/gh/mozilla-platform-ops/ronin_puppet.svg?style=svg)](https://app.circleci.com/pipelines/github/mozilla-platform-ops/ronin_puppet)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)

## structure

- `modules/`: modules (or component modules)
  - Usually only support a single operating system.
- `modules/roles_profiles/manifests/profiles`: profiles
  - Profiles provide an OS-independent interface to functionality provided by roles.
  - Where os detection and routing is done.
- `modules/roles_profiles/manifests/roles`
  - Roles specify everything a machine type needs to fufill a role.
  - Calls a single profile, maps to device groups.

### structural rules

- #1 Profiles can't call other profiles.
  - Goal is to have roles be completely transparent (at least at the top level).
  - Exception: Allowed when creating 'base' OS profiles.
- #2 Profiles can't be called/included inside (component) modules.
- #3 Hiera lookups should only be done within profiles and then passed as args to the class.

More information:
- https://puppet.com/docs/puppet/6/designing_system_configs_roles_and_profiles.html
- https://puppet.com/docs/puppet/6/the_roles_and_profiles_method.html#the_roles_and_profiles_method

## converging hosts

Many profiles run puppet at boot, but some only do on demand.

### bolt

```
# setup bolt first, see https://mana.mozilla.org/wiki/display/ROPS/M1+and+R8+Catalina+Deployment
bolt plan run deploy::apply -t macmini-r8-140.test.releng.mdc1.mozilla.com noop=false -v
```

## testing

### test-kitchen

[test-kitchen](https://docs.chef.io/workstation/kitchen/) (with [kitchen-puppet](https://github.com/neillturner/kitchen-puppet) ) provides infrastructure to automate running Puppet convergence and InSpec tests for each role.

The repo contains configurations for Test Kitchen to use Vagant, Docker, and Mac instances.

test-kitchen in called via `./bin/kitchen_docker` (the binary tells test-kitchen to use the `.kitchen_configs/kitchen_docker.yml` config file).

[InSpec](https://github.com/inspec/inspec) tests live in `tests/integration/SUITE/inspec/*_spec.rb`.

##### test-kitchen history

In the past we used `./bin/kitchen` (which used Vagrant and VirtualBox, and was configured in .kitchen_configs/kitchen.yml). `.kitchen_configs/kitchen.circleci.yml` was used for CircleCI (but it now uses the Docker config).

We used Vagrant/VirutalBox because some things don't work with Docker (kernel module installation and testing).

#### converging and running tests

```bash
# install ruby via homebrew or other means
brew install ruby
# add gem bin path (may differ on your system) to your PATH
export PATH=$PATH:/usr/local/lib/ruby/gems/2.6.0/bin  # may be 2.7.0
gem install bundler

# install testing tools
bundle install

## testing bitbar workers
./bin/kitchen_docker converge bitbar
# run spec tests
./bin/kitchen_docker verify bitbar

## testing linux-perf workers
# coverge host
./bin/kitchen_docker converge linux-perf
# run serverspec tests
./bin/kitchen_docker verify linux-perf
# login to host
./bin/kitchen_docker login linux-perf
```

#### creating a new suite

1. Edit `.kitchen.docker.yml`. Set the appropriate details.
1. (optional) Write spec tests.
  - Convergence is somewhat tolerant of failures. Write tests to ensure that the
    system is in the desired state. Tests help ensure that refactoring doesn't
    break things also.
  - See `tests/integration`.
1. Add the new suite to CircleCI.
  - See `.circleci/config.yml`.

### verifying production hosts

#### InSpec tests

The InSpec tests (see above) can be run on production hosts also.

```bash
inspec exec test/integration/linux/inspec/ -t ssh://t-linux64-ms-001.test.releng.mdc1.mozilla.com -i ~/.ssh/id_rsa --user=aerickson --sudo
```

### vagrant

[Vagrant](https://www.vagrantup.com/) is useful for testing the full masterless bootstrapping process (test-kitchen handles this normally).

Vagrant mounts this directory at /vagrant.

#### bitbar_devicepool role

```
gem install bundler
bundle install  ## .bundle/config sets the gemfile to .gemfile
vagrant up bionic-bare
vagrant ssh bionic-bare
sudo /vagrant/provisioners/linux/bootstrap_bitbar_devicepool.sh
```


## documentation

### module and class documentation

- style guide
  - https://www.puppet.com/docs/puppet/7/style_guide.html#style_guide_modules-documenting-code
- generate docs
  - https://www.puppet.com/docs/puppet/7/puppet_strings.html
