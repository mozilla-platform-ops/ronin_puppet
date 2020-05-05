# require 'spec_helper.rb'

describe command('timedatectl status') do
  its(:exit_status) { should eq 0 }
  # TODO: check clock sync... it doesn't work on freshly converged hosts though.
  its(:stdout) { should match /systemd-timesyncd.service active: yes/ }
end
