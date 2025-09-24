require_relative 'spec_helper'

only_if { os[:family] == 'ubuntu' && os[:release] == '18.04' }
describe command('timedatectl status') do
  its(:exit_status) { should eq 0 }
  # TODO: check clock sync... it doesn't work on freshly converged hosts though.
  its(:stdout) { should match /systemd-timesyncd.service active: yes/ }
end

only_if { os[:family] == 'ubuntu' && os[:release] == '22.04' }
describe command('timedatectl status') do
  its(:exit_status) { should eq 0 }

  # TODO: check output if we're synced. For 22.04 the output has changed.
end
