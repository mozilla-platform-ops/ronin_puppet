require_relative 'spec_helper'

describe 'Spotlight disabled and worker tasks non-indexed' do
  describe command('/usr/bin/mdutil -s /') do
    its(:stdout) { should match(/Indexing disabled|Spotlight server is disabled/) }
  end

  describe file('/opt/worker/tasks') do
    it { should be_directory }
  end

  describe file('/opt/worker/tasks/.metadata_never_index') do
    it { should be_file }
    it { should be_owned_by 'root' }
    it { should be_grouped_into 'wheel' }
    it { should be_mode 644 }
  end

  describe file('/opt/worker/tasks/.Spotlight-V100') do
    it { should_not exist }
  end
end

describe file('/usr/local/bin/kill_background_processes.sh') do
  it { should exist }
  it { should be_file }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'wheel' }
  it { should be_mode 755 }
end
