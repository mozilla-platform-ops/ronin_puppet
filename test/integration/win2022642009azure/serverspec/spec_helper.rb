ENV['PUPPET_ROLE'] ||= File.basename(File.expand_path('..', __dir__))
require_relative '../../windows/serverspec/spec_helper'
