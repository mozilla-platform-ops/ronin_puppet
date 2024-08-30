require_relative 'spec_helper'

# This test checks if the BluetoothAutoSeekKeyboard key is set to 1 in the Bluetooth preferences
describe 'Bluetooth preferences - Keyboard Auto Seek' do
  describe command('defaults read /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekKeyboard') do
    its(:stdout) { should match(/^1$/) }
  end
end

# This test checks if the BluetoothAutoSeekPointingDevice key is set to 0 in the Bluetooth preferences
describe 'Bluetooth preferences - Pointing Device Auto Seek' do
  describe command('defaults read /Library/Preferences/com.apple.Bluetooth BluetoothAutoSeekPointingDevice') do
    its(:stdout) { should match(/^0$/) }
  end
end
