require_relative 'spec_helper'

gpu_key = 'gpu'
driver_name = expected_hiera_value(gpu_key, 'name')

describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
  it { should exist }
end
