require_relative 'spec_helper'

vac_package_dir = expected_hiera_value('vac', 'package_dir')
vac_device_name = expected_hiera_value('vac', 'pnp_device_name')
vac_service_name = expected_hiera_value('vac', 'service_name')

describe file("C:\\VAC\\#{vac_package_dir}") do
  it { should exist }
  it { should be_directory }
end

describe service_property_command(vac_service_name, 'Name') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(vac_service_name)}\s*$/) }
end

describe powershell_command(<<~POWERSHELL) do
  $device = Get-PnpDevice -Class MEDIA -ErrorAction Stop |
    Where-Object { $_.FriendlyName -eq '#{vac_device_name}' } |
    Select-Object -First 1
  if ($null -eq $device) { exit 1 }
  $device.FriendlyName
POWERSHELL
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(vac_device_name)}\s*$/) }
end

gpu_key = 'gpu'
driver_name = expected_hiera_value(gpu_key, 'name')

describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
  it { should exist }
end
