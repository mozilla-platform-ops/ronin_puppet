require_relative 'spec_helper'

# cltbld can run tc without password
describe file('/etc/sudoers') do
  its(:content) { should match /cltbld\sALL=\(ALL\)\sNOPASSWD:\s\/sbin\/tc/ }
  its(:content) { should match /cltbld\sALL=\(ALL\)\sNOPASSWD:\s\/usr\/bin\/caddy/ }
end
