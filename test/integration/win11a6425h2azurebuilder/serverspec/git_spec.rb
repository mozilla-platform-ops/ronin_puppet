require_relative 'spec_helper'

describe software_property_command("$PSItem.DisplayName -match '^Git'", 'DisplayName') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^Git/i) }
end
