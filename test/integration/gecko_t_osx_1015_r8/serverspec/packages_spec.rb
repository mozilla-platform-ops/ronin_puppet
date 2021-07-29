require_relative 'spec_helper'

describe package('puppet_agent'), :if => os[:family] == 'Darwin' do
  it { should be_installed }
end
