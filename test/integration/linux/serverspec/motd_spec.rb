require 'spec_helper.rb'

describe file('/etc/motd') do
  it { should contain 'Unauthorized access prohibited' }
end