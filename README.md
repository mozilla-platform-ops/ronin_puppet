# Ronin Puppet: The masterless puppet collection
[![Build Status](https://travis-ci.com/mozilla-platform-ops/ronin_puppet.svg?branch=master)](https://travis-ci.com/mozilla-platform-ops/ronin_puppet)

## testing

```
brew install ruby
gem install bundler
bundle install --gemfile .gemfile
kitchen converge
kitchen verify
```
