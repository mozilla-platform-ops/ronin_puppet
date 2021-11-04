require_relative 'spec_helper'

describe 'users' do
  describe user('cltbld') do
    it { should exist }
    it { should belong_to_group 'cltbld' }
    it { should belong_to_group 'audio' }
    it { should belong_to_group 'video' }
  end
end
