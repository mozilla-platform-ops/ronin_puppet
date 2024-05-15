# see http://inspec.io/ or http://inspec.io/ for more info on inspec tests

describe directory('/tmp') do
  it { should exist }
end

# describe file('/tmp/funtimes.xyz') do
#   it { should exist }
# end

# describe file('/tmp/fun_haha.yyy') do
#   it { should exist }
#   it { should be_executable }
# end
