require_relative 'spec_helper'

# TODO: check /etc/sudoers

describe file('/etc/group') do
  its(:content) { should match /admin:x:[\n]+:jwatkins,dhouse,klibby,qfortier,mcornmesser,aerickson,rthijssen/ }
end
