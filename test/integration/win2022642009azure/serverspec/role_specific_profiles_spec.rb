require_relative 'spec_helper'

describe file('C:\\ProgramData\\Google') do
  it { should exist }
  it { should be_directory }
end

describe file('C:\\ProgramData\\Google\\Auth') do
  it { should exist }
  it { should be_directory }
end
