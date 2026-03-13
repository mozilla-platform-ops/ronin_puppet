require_relative 'spec_helper'

expected_nssm_version = expected_hiera_value('nssm', 'version')
expected_taskcluster_version = expected_hiera_value('taskcluster', 'version')

describe file("C:\\nssm\\nssm-#{expected_nssm_version}\\win64\\nssm.exe") do
  it { should exist }
end

describe powershell_command("(Get-Service 'worker-runner' -ErrorAction Stop).Name") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^worker-runner\s*$/) }
end

{
  'C:\\generic-worker\\generic-worker.exe' => 'generic-worker',
  'C:\\worker-runner\\start-worker.exe' => 'worker-runner',
  'C:\\generic-worker\\taskcluster-proxy.exe' => 'taskcluster-proxy',
  'C:\\generic-worker\\livelog.exe' => 'livelog'
}.each do |path, _label|
  describe file(path) do
    it { should exist }
  end

  describe powershell_command("& '#{path}' --short-version") do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{Regexp.escape(expected_taskcluster_version)}\s*$/) }
  end
end
