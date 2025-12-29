require_relative 'spec_helper'

describe file('/etc/motd') do
  it { should contain 'Unauthorized access prohibited' }
end
