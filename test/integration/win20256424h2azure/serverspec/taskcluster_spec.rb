require_relative 'spec_helper'

describe powershell_command("(Get-Acl 'C:\\worker-runner\\runner.yml').GetOwner([System.Security.Principal.SecurityIdentifier]).Value") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^S-1-5-18\s*$/) }
end
