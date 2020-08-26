require_relative 'spec_helper'

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
end

describe file('/etc/group') do
  its(:content) { should match /admin:x:[\d]+:jwatkins,dhouse,mcornmesser,aerickson,rthijssen/ }
end
