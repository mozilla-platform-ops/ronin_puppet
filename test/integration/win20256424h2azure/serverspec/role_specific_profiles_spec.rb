require_relative '../../windows/serverspec/spec_helper'

driver_name = expected_hiera_value('gpu', 'name')

describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
  it { should exist }
end
