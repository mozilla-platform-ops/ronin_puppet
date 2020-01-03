require 'spec_helper.rb'

describe command('timedatectl status') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Time zone: Etc\/UTC/ }
end