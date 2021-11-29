require_relative 'spec_helper'

describe command('timedatectl status') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Time zone: Etc\/UTC/ }
end
