#!/usr/bin/env ruby
# frozen_string_literal: true

# Wrapper to run kitchen with a clean environment.
#
# Problem: kitchen runs puppet via "sudo -E", which passes ALL env vars
# to puppet's embedded Ruby. If bundler vars (BUNDLE_GEMFILE, GEM_HOME,
# GEM_PATH) are present, puppet's Ruby auto-loads our bundler and fails
# with GemNotFound because puppet's gems differ from ours.
#
# Solution: load bundler/setup to resolve gems (sets up $LOAD_PATH),
# then DELETE bundler/gem vars from ENV before loading kitchen.
# $LOAD_PATH is process-internal and doesn't propagate to child
# processes, so puppet stays clean.

require "bundler/setup"

# Strip all bundler/gem vars from the environment.
# Kitchen inherits the correct $LOAD_PATH from bundler/setup above,
# but child processes (puppet via sudo -E) won't see these vars.
%w[
  BUNDLE_GEMFILE
  BUNDLE_PATH
  BUNDLE_BIN_PATH
  BUNDLE_APP_CONFIG
  GEM_HOME
  GEM_PATH
  RUBYOPT
].each { |key| ENV.delete(key) }

load Gem.bin_path("test-kitchen", "kitchen")
