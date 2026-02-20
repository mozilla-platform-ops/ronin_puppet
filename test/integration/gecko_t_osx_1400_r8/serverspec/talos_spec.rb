require_relative 'spec_helper'

describe 'Talos build directories' do
  [
    '/opt/builds/slave',
    '/opt/builds/slave/talos-data',
    '/opt/builds/slave/talos-data/talos',
    '/opt/builds/git-shared',
    '/opt/builds/hg-shared',
    '/opt/builds/tooltool_cache',
  ].each do |dir|
    describe file(dir) do
      it { should be_directory }
      it { should be_owned_by 'cltbld' }
      it { should be_grouped_into 'staff' }
      it { should be_mode 755 }
    end
  end
end
