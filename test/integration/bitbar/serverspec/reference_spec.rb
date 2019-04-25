#----------------------------------------------------------------------
# instantiating testing requirements
#----------------------------------------------------------------------

if (!ENV['w_ssh'].nil? && ENV['w_ssh'] = 'true')
  begin
    require 'spec_helper.rb'
  rescue LoadError
  end
else
  begin
    require 'spec_helper.rb'
    set :backend, :exec
  rescue LoadError
  end
end

#  http://serverspec.org/resource_types.html

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
