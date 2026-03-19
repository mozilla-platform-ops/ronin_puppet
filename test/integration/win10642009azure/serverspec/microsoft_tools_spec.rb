require_relative 'spec_helper'

ronin_dir = 'C:\\ProgramData\\PuppetLabs\\ronin'

describe software_property_command("$_.DisplayName -like 'WPTx64*'", 'DisplayName') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^WPTx64/i) }
end

describe file("#{ronin_dir}\\mozprofilerprobe.mof") do
  it { should exist }
end

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
