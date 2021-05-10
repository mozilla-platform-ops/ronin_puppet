# frozen_string_literal: true

require 'beaker-task_helper/inventory'
require 'bolt_spec/run'
require 'puppet'
require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'
require 'puppetlabs_spec_helper/module_spec_helper'

run_puppet_install_helper
install_ca_certs
install_module_on(hosts)
install_module_dependencies_on(hosts)

base_dir = File.dirname(File.expand_path(__FILE__))

UNSUPPORTED_PLATFORMS = %w[Solaris AIX].freeze

base_dir = File.dirname(File.expand_path(__FILE__))

RSpec.configure do |c|
  # Readable test descriptions
  c.formatter = :documentation

  # should we just use rspec_puppet
  c.add_setting :module_path
  c.module_path = File.join(base_dir, 'fixtures', 'modules')
end
