# Ronin Puppet: the masterless puppet collection
[![Build Status](https://travis-ci.com/mozilla-platform-ops/ronin_puppet.svg?branch=master)](https://travis-ci.com/mozilla-platform-ops/ronin_puppet)

## structure

```
modules/roles_profiles/manifests/roles
modules/roles_profiles/manifests/profiles
```

Roles and profiles are both types of Puppet modules.

- Roles specify everything a machine type needs to fufill a role.
- Profiles provide an OS-independent interface to functionality provided by roles.

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
- Some tests don't work with Docker.
  - virtualBox hosts are more like hardware Ubuntu hosts (startup services, kernel modules).
- Docker is faster?

[serverspec](https://serverspec.org/) tests live in `tests/integration/SUITE/*_spec.rb`.

#### converging and running tests

```
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

	```
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

	```
	include roles_profiles::roles::your_favorite_role
	```

1. (optional) Write spec tests. 

    Convergence is somewhat tolerant of failures. Write tests to ensure that the
    system is in the desired state. Tests help ensure that refactoring doesn't
    break things also.

	See `tests/integration`.

1. Add the new suite to Travis.

    See `.travis.yml`.