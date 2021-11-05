require_relative 'spec_helper'

describe file('/etc/motd') do
  its('content') { should match /Unauthorized access prohibited/ }
end
