require_relative 'spec_helper'

# This test checks if Wi-Fi is disabled
describe 'Wi-Fi disabled check' do
  wifi_interface = nil

  describe 'Detect Wi-Fi interface' do
    it 'identifies the correct Wi-Fi interface' do
      output = command("networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}'").stdout.strip
      wifi_interface = output
      puts "Detected Wi-Fi interface: #{wifi_interface}"
      expect(wifi_interface).not_to be_empty
    end
  end

  if wifi_interface
    describe "Check if Wi-Fi is disabled on interface #{wifi_interface}" do
      it "should be turned off" do
        result = command("/usr/sbin/networksetup -getairportpower #{wifi_interface}")
        expect(result.stdout).to match(/Off/)
      end
    end
  end
end
