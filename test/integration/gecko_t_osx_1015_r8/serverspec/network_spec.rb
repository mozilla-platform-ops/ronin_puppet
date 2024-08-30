require_relative 'spec_helper'

# This test checks if Wi-Fi is disabled
describe 'Wi-Fi disabled check' do
  wifi_interface = if os[:family] == 'darwin'
                     command('networksetup -listallhardwareports | grep -A 1 "Wi-Fi" | awk \'/Device/ {print $2}\'').stdout.strip
                   else
                     fail('This test is only supported on macOS')
                   end

  it 'disables Wi-Fi on the correct interface' do
    expect(wifi_interface).not_to be_empty
    result = command("/usr/sbin/networksetup -getairportpower #{wifi_interface}")
    expect(result.stdout).to match(/Off/)
  end
end
