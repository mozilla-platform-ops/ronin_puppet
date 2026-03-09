require_relative 'spec_helper'

describe 'Spotlight re-enabled and worker tasks indexable' do
  describe command('/usr/bin/mdutil -s /') do
    its(:stdout) { should match(/Indexing enabled/) }
  end

  describe file('/opt/worker/tasks') do
    it { should be_directory }
  end

  describe file('/opt/worker/tasks/.metadata_never_index') do
    it { should_not exist }
  end
end

describe file('/usr/local/bin/kill_background_processes.sh') do
  it { should_not exist }
end
