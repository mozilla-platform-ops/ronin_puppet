require_relative 'spec_helper'

# This test checks if Wi-Fi is disabled
describe 'Wi-Fi disabled check' do
  wifi_interface = nil

  describe 'Detect Wi-Fi interface' do
    it 'identifies the correct Wi-Fi interface' do
      output = command("networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/ {getline; print $NF}'").stdout.strip
      wifi_interface = output unless output.empty?

      # Fallback to common interfaces if detection fails
      wifi_interface ||= 'en0' if command('networksetup -getairportpower en0').exit_status == 0
      wifi_interface ||= 'en1' if command('networksetup -getairportpower en1').exit_status == 0

      puts "Detected Wi-Fi interface: #{wifi_interface}" if wifi_interface
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
