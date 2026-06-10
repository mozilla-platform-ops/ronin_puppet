require_relative 'spec_helper'

if WORKER_FUNCTION == 'tester'
  gpu_key = ROLE_NAME == 'win116425h2azure' ? 'gpu_a10' : 'gpu'
  driver_name = expected_hiera_value(gpu_key, 'name')

  describe file("C:\\Windows\\Temp\\#{driver_name}.exe") do
    it { should exist }
  end
end

if ROLE_NAME == 'win11a6425h2azurebuilder'
  describe file('C:\\ProgramData\\Google') do
    it { should exist }
    it { should be_directory }
  end

  describe file('C:\\ProgramData\\Google\\Auth') do
    it { should exist }
    it { should be_directory }
  end
end
