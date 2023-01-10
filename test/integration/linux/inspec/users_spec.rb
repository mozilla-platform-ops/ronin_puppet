require_relative 'spec_helper'

# check that some users exist
describe 'users' do
  describe user('aerickson') do
    it { should exist }
  end

  describe user('dhouse') do
    it { should exist }
  end
end

describe file('/etc/group') do
  # check that relops users are in the admin group
  its(:content) { should match /admin:x:[\d]+:.*mcornmesser.*/ }
  its(:content) { should match /admin:x:[\d]+:.*dhouse.*/ }
  its(:content) { should match /admin:x:[\d]+:.*mgoossens.*/ }
  its(:content) { should match /admin:x:[\d]+:.*jmoss.*/ }
  its(:content) { should match /admin:x:[\d]+:.*aerickson.*/ }
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
