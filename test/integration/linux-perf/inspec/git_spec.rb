require_relative 'spec_helper'
require 'rubygems/version'

describe package('git'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

if os.family == 'debian' && ['18.04', '22.04'].include?(os.release)
describe command('git --version') do
    its('stdout') { should eq "git version 2.42.0\n" }
    its('exit_status') { should eq 0 }
end
elsif os.family == 'debian' && ['24.04'].include?(os.release)
describe command('git --version') do
    it 'reports Git 2.43.0 or newer' do
      version = subject.stdout.strip.sub(/\Agit version /, '')
      expect(Gem::Version.new(version)).to be >= Gem::Version.new('2.43.0')
    end
    its('exit_status') { should eq 0 }
end
end
