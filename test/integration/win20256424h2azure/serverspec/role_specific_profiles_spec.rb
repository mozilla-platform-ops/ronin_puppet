require_relative '../../windows/serverspec/spec_helper'

driver_name = expected_hiera_value('gpu', 'name')

describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
  it { should exist }
end

if ENV.fetch('WORKER_POOL_ID', '').include?('gpu')
  driver_version = driver_name.split('_').first

  describe powershell_command(<<~POWERSHELL) do
    nvidia-smi.exe --query-gpu=name,driver_version --format=csv,noheader
    if (-not $?) { exit 1 }
  POWERSHELL
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^NVIDIA A10-8Q,\s*#{Regexp.escape(driver_version)}\s*$/) }
  end
end
