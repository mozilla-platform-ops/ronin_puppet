require_relative 'spec_helper'

describe file('/etc/default/locale') do
  its('content') { should match /LANG=en_US.UTF-8/ }
  its('content') { should match /LANGUAGE="en_US:en"/ }
end
