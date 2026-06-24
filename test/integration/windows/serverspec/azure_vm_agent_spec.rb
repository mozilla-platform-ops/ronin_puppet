require_relative 'spec_helper'

expected_version = expected_hiera_value('azure', 'vm_agent', 'version').split('_').first

describe software_property_command("$_.DisplayName -like 'Windows Azure VM Agent*'", 'DisplayVersion') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(expected_version)}\s*$/) }
end
