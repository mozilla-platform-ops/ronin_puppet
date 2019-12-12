require 'spec_helper.rb'

describe 'users' do
  describe user('aerickson') do
    it { should exist }
  end

  describe user('jwatkins') do
    it { should exist }
  end

  describe user('dhouse') do
    it { should exist }
  end

  describe user('fubar') do
    it { should exist }
  end
end