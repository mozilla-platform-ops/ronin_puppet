require_relative 'spec_helper'

# The image caches the NVIDIA GRID installer. The driver installs at boot
# only on worker pools with gpu in the pool ID.
describe powershell_command(<<~POWERSHELL) do
  $installer = Get-ChildItem -Path 'C:\\Windows\\Temp' -Filter '*_grid_*.exe' | Select-Object -First 1
  if ($installer -and $installer.Length -gt 100000000) { exit 0 } else { exit 1 }
POWERSHELL
  its(:exit_status) { should eq 0 }
end
