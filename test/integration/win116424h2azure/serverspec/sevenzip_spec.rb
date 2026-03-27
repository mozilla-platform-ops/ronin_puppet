require_relative 'spec_helper'

describe software_property_command("$_.DisplayName -like '*Zip*'", 'DisplayVersion') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^25\.00/) }
end
