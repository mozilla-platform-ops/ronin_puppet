require_relative 'spec_helper'

describe 'NTP configuration' do
  describe command('sudo systemsetup -getusingnetworktime') do
    its(:stdout) { should match(/Network Time: On/) }
  end

  describe command('sudo systemsetup -getnetworktimeserver') do
    its(:stdout) { should match(/ntp\.build\.mozilla\.org/) }
  end
end
