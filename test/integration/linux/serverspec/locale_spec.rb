require_relative 'spec_helper'

describe file('/etc/default/locale') do
  it { should contain 'LANG=en_US.UTF-8' }
  it { should contain 'LANGUAGE="en_US:en"' }
end
