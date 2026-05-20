require_relative 'spec_helper'

x64_tester = %w[win116424h2azure win116425h2azure].include?(ROLE_NAME)

if WORKER_FUNCTION == 'tester'
  gpu_key = ROLE_NAME == 'win116425h2azure' ? 'gpu_a10' : 'gpu'
  driver_name = expected_hiera_value(gpu_key, 'name')

  # GRID install completes only after reboot, which kitchen does not perform
  # mid-converge. Full install + nvidia-smi verification has to happen as part
  # of worker image validation on a real A10 pool. The size check catches the
  # case where the blob mirror returns a placeholder or 0-byte file. Serverspec
  # on the winrm backend does not implement file.size, so we shell out.
  describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
    it { should exist }
  end

  describe powershell_command(
    "if ((Get-Item 'C:\\Windows\\Temp\\#{driver_name}.exe').Length -gt 100000000) " \
    "{ exit 0 } else { exit 1 }"
  ) do
    its(:exit_status) { should eq 0 }
  end
end

if x64_tester
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
end

if ROLE_NAME == 'win11a6425h2azurebuilder'
  describe file('C:\\ProgramData\\Google') do
    it { should exist }
    it { should be_directory }
  end

  describe file('C:\\ProgramData\\Google\\Auth') do
    it { should exist }
    it { should be_directory }
  end
end
