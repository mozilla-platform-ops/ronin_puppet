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
#----------------------------------------------------------------------

#  http://serverspec.org/resource_types.html

#----------------------------------------------------------------------
# testing basic service
#----------------------------------------------------------------------
# describe package('lighttpd') do
#   it { should be_installed }
# end

# describe service('lighttpd') do
#   it { should be_enabled }
# end

# describe service('lighttpd') do
#   it { should be_running }
# end

describe user('bclary') do
  it { should exist }
end

describe user('aerickson') do
  it { should exist }
end

describe user('bitbar') do
  it { should exist }
end

## windows only
# describe service('devicepool') do
#   it { should be_installed }
# end

#----------------------------------------------------------------------
# testing basic function
#----------------------------------------------------------------------

# describe command('curl http://127.0.0.1/test.html') do
#   its(:stdout) { should match(/Welcome/) }
# end

#----------------------------------------------------------------------
