require_relative 'spec_helper'

describe powershell_command(File.read(File.join(ROOT_DIR, 'test', 'windows_maintenance.ps1'))) do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should include('Windows maintenance checks passed.') }
end
