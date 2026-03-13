require_relative 'spec_helper'

describe powershell_command("(Get-Command 'git.exe' -ErrorAction Stop).Source") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/git\.exe/i) }
end
