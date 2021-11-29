require_relative 'spec_helper'

describe 'reference-tests' do
  describe command('systemctl status bogus_service_939122') do
    # code 4 is unknown
    its(:exit_status) { should eq 4 }
  end

  describe command('systemctl status ssh') do
    # code 0 is running
    its(:exit_status) { should eq 0 }
  end
end
