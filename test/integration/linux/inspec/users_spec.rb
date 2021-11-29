require_relative 'spec_helper'

describe 'users' do
  describe user('aerickson') do
    it { should exist }
  end

  describe user('dhouse') do
    it { should exist }
  end
end

describe file('/etc/group') do
  its(:content) { should match /admin:x:[\d]+:dhouse,mcornmesser,aerickson,rthijssen/ }
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

  # ensure common relops key is present
  # - have to escape the '+', ugh.
  its('content') { should match /AAAAC3NzaC1lZDI1NTE5AAAAILB0k0dwdH7h8j\+zRPprLFeTgRwkgI6mcjQCeEoaqOY2/ }
end
