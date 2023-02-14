require_relative 'spec_helper'

describe 'users' do
  describe user('aerickson') do
    it { should exist }
  end

  describe user('mgoossens') do
    it { should exist }
  end
end
