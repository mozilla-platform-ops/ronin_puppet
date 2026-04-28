require_relative 'spec_helper'

vac_version = expected_hiera_value('vac', 'version')
vac_display_version = "#{vac_version[0]}.#{vac_version[1..]}"

describe file("C:\\VAC\\vac#{vac_version}") do
  it { should exist }
  it { should be_directory }
end

describe software_property_command("$_.DisplayName -like 'Virtual Audio Cable*'", 'DisplayVersion') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(vac_display_version)}\s*$/) }
end

gpu_key = 'gpu'
driver_name = expected_hiera_value(gpu_key, 'name')

describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
  it { should exist }
end
