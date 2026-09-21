require_relative 'spec_helper'

if TASK_DRIVE == 'C:'
  describe registry_value_command('HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment', 'HG_CACHE') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^C:\\hg-cache\s*$/) }
  end

  describe registry_value_command('HKLM:\\SOFTWARE\\Mozilla\\ronin_puppet', 'task_drive') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^C:\s*$/) }
  end

  describe registry_value_command('HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management', 'PagingFiles') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^C:\\pagefile\.sys 8192 8192\s*$/) }
    its(:stdout) { should_not match(/D:\\/i) }
  end

  %w[tasks caches downloads].each do |directory|
    describe file('C:\\worker-runner\\runner.yml') do
      its(:content) { should match(/^\s+#{directory}Dir: 'C:\\#{directory}'\s*$/) }
    end
  end

  describe file('C:\\hg-shared') do
    it { should be_directory }
  end

end
