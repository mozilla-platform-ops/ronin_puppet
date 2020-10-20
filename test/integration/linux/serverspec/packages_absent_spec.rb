require_relative 'spec_helper'

# absent packages

describe package('gnome-calendar'), :if => os[:family] == 'ubuntu' do
  it { should_not be_installed }
end

describe package('update-manager'), :if => os[:family] == 'ubuntu' do
  it { should_not be_installed }
end

describe package('update-manager-core'), :if => os[:family] == 'ubuntu' do
  it { should_not be_installed }
end

describe package('ubuntu-release-upgrader-core'), :if => os[:family] == 'ubuntu' do
  it { should_not be_installed }
end
