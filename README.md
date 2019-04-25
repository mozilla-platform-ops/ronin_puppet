# Ronin Puppet: The masterless puppet collection
[![Build Status](https://travis-ci.com/mozilla-platform-ops/ronin_puppet.svg?branch=master)](https://travis-ci.com/mozilla-platform-ops/ronin_puppet)

## structure

Roles live at modules/roles_profiles/manifests/roles.

## testing

```
brew install ruby
gem install bundler
bundle install --gemfile .gemfile
kitchen converge
kitchen verify
```
