require_relative 'spec_helper'

describe file('/etc/sudoers') do
  its(:content) { should contain "%admin	ALL=(ALL)	NOPASSWD: ALL" }
end
