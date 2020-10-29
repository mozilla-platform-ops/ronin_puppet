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

# root should have * pw
describe file('/etc/shadow') do
  its(:content) { should match /^root:\*:/ }
end

# relops should have * pw
describe file('/etc/shadow') do
  its(:content) { should match /^relops:\*:/ }
end

# root should have no ssh keys
describe file('/root/.ssh/authorized_keys') do
  it { should_not exist }
end

# relops should have a bunch of keys in ~/.ssh/authorized_keys
describe file('/home/relops/.ssh/authorized_keys') do
  it { should exist }

  # check that we're going through relops users
  its(:content) { should match /keys for dhouse/ }
  # check that there's some key content in dhouse's entry
  its(:content) { should match /ssh-rsa [\w\+\/\=]+ dhouse.house/ }

  # relops is a special user that should always be present
  its(:content) { should match /keys for relops/ }
  # check that there's some key content in the relops entry
  its(:content) { should match /ssh-ed25519 [\w\+]+ Relops ed25519 Key/ }
end
