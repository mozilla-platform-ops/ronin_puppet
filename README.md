# Ronin Puppet: the masterless puppet collection
[![Build Status](https://travis-ci.com/mozilla-platform-ops/ronin_puppet.svg?branch=master)](https://travis-ci.com/mozilla-platform-ops/ronin_puppet)

## structure

```
modules/roles_profiles/manifests/roles
modules/roles_profiles/manifests/profiles
```

Roles specify everything a machine type needs to fufill a role.

Profiles provide an OS-independent interface to functionality provided by modules.

## testing

### vagrant

[Vagrant](https://www.vagrantup.com/) is useful for testing the full masterless bootstrapping process.

Vagrant mounts this directory at /vagrant.

#### bitbar_devicepool role

```
gem install bundler
bundle install --gemfile .gemfile
vagrant up bionic
vagrant ssh bionic
echo 'bitbar_devicepool' > /etc/puppet_role
sudo /vagrant/provisioners/linux/bootstrap_bitbar_devicepool.sh
```

### kitchen-puppet (automated and serverspec testing)

kitchen-puppet provides infrastructure to automate running convergence and serverspec tests for each role.

Uses [kitchen-puppet](https://github.com/neillturner/kitchen-puppet).

```
gem install bundler
bundle install --gemfile .gemfile
kitchen converge
kitchen verify
```

New test suites can be added in .kitchen.yaml.

[serverspec](https://serverspec.org/) tests live in `tests/integration/SUITE/*_spec.rb`.
