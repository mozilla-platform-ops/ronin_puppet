require_relative 'spec_helper'

if ENV.fetch('WORKER_POOL_ID', '').include?('gpu')
  driver_version = expected_hiera_value('gpu', 'name').split('_').first

  describe powershell_command(<<~POWERSHELL) do
    nvidia-smi.exe --query-gpu=name,driver_version --format=csv,noheader
    if (-not $?) { exit 1 }
  POWERSHELL
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^NVIDIA A10-8Q,\s*#{Regexp.escape(driver_version)}\s*$/) }
  end

end
