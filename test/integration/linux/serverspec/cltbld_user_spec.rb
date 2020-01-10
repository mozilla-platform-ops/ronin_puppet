require 'spec_helper.rb'

describe 'users' do
  describe user('cltbld') do
    it { should exist }
    it { should belong_to_group 'cltbld' }
  end
end