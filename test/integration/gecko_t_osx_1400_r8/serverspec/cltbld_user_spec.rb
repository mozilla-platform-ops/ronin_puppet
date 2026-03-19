require_relative 'spec_helper'

describe 'users' do
  describe user('cltbld') do
    it { should exist }
    it { should belong_to_group '_developer' }
    it { should belong_to_group 'com.apple.access_screensharing' }
    it { should belong_to_group 'com.apple.access_ssh' }
  end
end
