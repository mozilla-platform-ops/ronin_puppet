require_relative 'spec_helper'

x64_tester = %w[win116424h2azure win116425h2azure].include?(ROLE_NAME)

if WORKER_FUNCTION == 'tester'
  gpu_key = ROLE_NAME == 'win116425h2azure' ? 'gpu_a10' : 'gpu'
  driver_name = expected_hiera_value(gpu_key, 'name')
  driver_installer = "C:\\Windows\\Temp\\#{driver_name}.exe"

  describe file(driver_installer) do
    it { should exist }
  end

  describe powershell_command(
    "if ((Get-Item '#{driver_installer}').Length -gt 100000000) " \
    "{ exit 0 } else { exit 1 }"
  ) do
    its(:exit_status) { should eq 0 }
  end

  describe powershell_command(<<~POWERSHELL) do
    $driverName = 'ronin_puppet_offline_nvidia_grid_test'
    $driverPath = "C:\\Windows\\Temp\\$driverName.exe"
    $manifestPath = "C:\\Windows\\Temp\\$driverName.pp"
    $puppetLog = "C:\\Windows\\Temp\\$driverName.log"
    Set-Content -Path $driverPath -Value 'preseeded installer' -NoNewline -Encoding ASCII
    try {
      $env:FACTER_custom_win_gpu = 'no'
      $env:FACTER_custom_win_temp_dir = 'C:\\Windows\\Temp'
      $env:NO_COLOR = '1'
      $puppet = Join-Path ${env:ProgramFiles} 'Puppet Labs\\Puppet\\bin\\puppet.bat'
      if (-not (Test-Path $puppet)) {
        $puppet = Join-Path ${env:ProgramFiles} 'Puppet Labs\\Puppet\\bin\\puppet'
      }
      @"
class { 'win_packages::drivers::nvidia_grid':
  driver_name  => '$driverName',
  display_name => 'NVIDIA Offline Cache Test',
  srcloc       => 'https://127.0.0.1:9/unreachable',
}
"@ | Set-Content -Path $manifestPath -NoNewline -Encoding ASCII
      & $puppet apply `
        '--color=false' `
        '--modulepath=C:\\ronin_puppet\\modules;C:\\ronin_puppet\\r10k_modules' `
        '--detailed-exitcodes' `
        $manifestPath *> $puppetLog
      $puppetExitCode = $LASTEXITCODE
      if ($puppetExitCode -notin 0, 2) {
        $puppetOutput = Get-Content -Path $puppetLog -Raw -ErrorAction SilentlyContinue
        if ($puppetOutput) {
          $puppetOutput -replace "$([char]27)\[[0-9;]*[A-Za-z]", '' | Write-Output
        }
        exit $puppetExitCode
      }
    }
    finally {
      Remove-Item -Path $driverPath,$manifestPath,$puppetLog -Force -ErrorAction SilentlyContinue
    }
  POWERSHELL
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
