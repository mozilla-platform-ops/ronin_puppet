require_relative 'spec_helper'

describe file('C:\\Windows') do
  it { should be_directory }
end
