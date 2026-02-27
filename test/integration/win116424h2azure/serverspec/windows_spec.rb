require_relative 'spec_helper'

describe file('C:\\Windows') do
  it { should be_directory }
end

describe file('C:\\Program Files\\Puppet Labs\\Puppet') do
  it { should be_directory }
end

describe file('C:\\mozilla-build') do
  it { should be_directory }
end
