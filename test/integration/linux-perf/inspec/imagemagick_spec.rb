require_relative 'spec_helper'

# 6.x
describe package('imagemagick'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end
