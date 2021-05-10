# frozen_string_literal: true

require 'bolt'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

$LOAD_PATH.unshift File.join(__dir__, 'lib')

# Ensure tasks are enabled when rspec-puppet sets up an environment
# so we get task loaders.
Puppet[:tasks] = true
