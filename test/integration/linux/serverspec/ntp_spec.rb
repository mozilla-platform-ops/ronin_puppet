require 'spec_helper.rb'

describe command('timedatectl status'), :type => :broken_on_ci do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /System clock synchronized: yes/ }
end