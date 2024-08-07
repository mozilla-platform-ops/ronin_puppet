require_relative 'spec_helper'

describe 'users' do
  describe user('cltbld') do
    it { should exist }

    %w(cltbld cltbld audio video).each do |group|
      its('groups') { should include group }
    end
  end
end
