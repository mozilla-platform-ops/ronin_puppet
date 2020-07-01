# Ronin Puppet: the masterless puppet collection

[![Build Status](https://travis-ci.com/mozilla-platform-ops/ronin_puppet.svg?branch=master)](https://travis-ci.com/mozilla-platform-ops/ronin_puppet)
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

For more information see: https://puppet.com/docs/pe/2018.1/the_roles_and_profiles_method.html

## testing

### vagrant

[Vagrant](https://www.vagrantup.com/) is useful for testing the full masterless bootstrapping process.

Vagrant mounts this directory at /vagrant.

#### bitbar_devicepool role

```
gem install bundler
bundle install  ## .bundle/config sets the gemfile to .gemfile
vagrant up bionic-bare
vagrant ssh bionic-bare
sudo /vagrant/provisioners/linux/bootstrap_bitbar_devicepool.sh
```


### kitchen-puppet

[kitchen-puppet](https://github.com/neillturner/kitchen-puppet) provides infrastructure to
automate running convergence and serverspec tests for each role.

The `.kitchen.yml` config uses Vagrant and virtualBox, while the `.kitchen.docker.yml` config uses Docker.

- Docker is the only way we can test on Travis.
- Some tests don't work with Docker (kernel module tests).
- Docker is faster (~1 minute faster on a converge from a new image).

[serverspec](https://serverspec.org/) tests live in `tests/integration/SUITE/*_spec.rb`.

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
./bin/kitchen converge bitbar
# run spec tests
./bin/kitchen verify bitbar

## testing linux workers
# coverge host
./bin/kitchen converge linux
# run serverspec tests
./bin/kitchen verify linux
# login to host
./bin/kitchen login linux
```

#### creating a new suite

1. Edit `.kitchen.yml` and `.kitchen.docker.yml`. Set the appropriate details.
1. Create a new manifest dir for the suite.

  ```bash
  cd manifests-kitchen
  mkdir <suite_name>
  cd <suite_name>
  ln -s ../../manifests/site.pp .
  touch z-<suite_name>.pp
  vim z-<suite_name>.pp
  ```

  We need our pp file to be run after the site.pp, that's why it starts with a z.

1. Include your desired role

  In the recently created `z-<suite_name>.pp`:

  ```puppet
  include roles_profiles::roles::your_favorite_role
  ```

1. (optional) Write spec tests.

    Convergence is somewhat tolerant of failures. Write tests to ensure that the
    system is in the desired state. Tests help ensure that refactoring doesn't
    break things also.

  See `tests/integration`.

1. Add the new suite to Travis.

    See `.travis.yml`.

#### test-kitchen TODOS

- refactor kitchen testing
  - rename linux kitchen env to base
  - create a talos kitchen env for non-base
