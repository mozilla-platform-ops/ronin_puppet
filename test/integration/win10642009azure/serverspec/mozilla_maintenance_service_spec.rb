require_relative 'spec_helper'

describe software_property_command("$_.DisplayName -eq 'Mozilla Maintenance Service'", 'DisplayName') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^Mozilla Maintenance Service\s*$/) }
end
