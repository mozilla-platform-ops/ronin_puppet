require_relative 'spec_helper'

describe plist('/Library/Preferences/com.apple.Bluetooth.plist') do
  its('BluetoothAutoSeekKeyboard') { should eq 0 }
  its('BluetoothAutoSeekPointingDevice') { should eq 0 }
end
