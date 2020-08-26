require_relative 'spec_helper'

describe file('/etc/sudoers') do
  its(:content) { should match /%admin\sALL=\(ALL\)\sNOPASSWD:\sALL/ }
end
