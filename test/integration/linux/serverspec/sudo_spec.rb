require_relative 'spec_helper'

describe file('/etc/sudoers') do
  its(:content) { should contain "%admin	ALL=(ALL)	NOPASSWD: ALL" }
end

describe file('/etc/group') do
  its(:content) { should match /admin:x:[\d]+:jwatkins,dhouse,klibby,qfortier,mcornmesser,aerickson,rthijssen/ }
end
