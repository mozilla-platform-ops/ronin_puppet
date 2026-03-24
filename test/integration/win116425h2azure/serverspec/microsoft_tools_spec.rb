require_relative 'spec_helper'

ronin_dir = 'C:\\ProgramData\\PuppetLabs\\ronin'
dxsdk_dir = 'C:\\Program Files (x86)\\Microsoft DirectX SDK (June 2010)'

describe software_property_command("$_.DisplayName -like 'WPTx64*'", 'DisplayName') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^WPTx64/i) }
end

describe file("#{ronin_dir}\\mozprofilerprobe.mof") do
  it { should exist }
end

if WORKER_FUNCTION == 'tester'
  %w[
    xperf_kernel_start.ps1
    xperf_kernel_stop.ps1
    xperf_register_tasks.ps1
  ].each do |script_name|
    describe file("#{ronin_dir}\\#{script_name}") do
      it { should exist }
    end
  end

  {
    'xperf_kernel_trace_start' => 'xperf_kernel_start.ps1',
    'xperf_kernel_trace_stop' => 'xperf_kernel_stop.ps1'
  }.each do |task_name, script_name|
    describe scheduled_task_command(task_name, '$task.Actions | Select-Object -First 1 | Select-Object -ExpandProperty Execute') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/powershell\.exe\s*$/i) }
    end

    describe scheduled_task_command(task_name, '$task.Actions | Select-Object -First 1 | Select-Object -ExpandProperty Arguments') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/#{Regexp.escape("#{ronin_dir}\\#{script_name}")}/i) }
    end
  end
end

%w[x86 x64].each do |arch|
  describe software_property_command("$_.DisplayName -match '^Microsoft Visual C\\+\\+ 2015-2022 Redistributable \\(#{arch}\\)'", 'DisplayVersion') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^14\.\d+\.\d+(?:\.\d+)?\s*$/) }
  end
end

if ROLE_NAME == 'win11a6425h2azurebuilder'
  describe powershell_command("(Get-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -ErrorAction Stop).State") do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^Enabled\s*$/i) }
  end

  describe machine_env_command('DXSDK_DIR') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{Regexp.escape(dxsdk_dir)}\s*$/) }
  end

  describe file("#{dxsdk_dir}\\Include\\audiodefs.h") do
    it { should exist }
  end

  describe software_property_command("$_.DisplayName -eq 'Microsoft BinScope 2014'", 'DisplayVersion') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^7\.0\.7000\.0\s*$/) }
  end

  %w[x86 x64].each do |arch|
    describe software_property_command("$_.DisplayName -match '^Microsoft Visual C\\+\\+ 2015.*\\(#{arch}\\)'", 'DisplayVersion') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/^14\.0\.23918(?:\.\d+)?\s*$/) }
    end
  end
end
